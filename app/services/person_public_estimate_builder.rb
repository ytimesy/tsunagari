class PersonPublicEstimateBuilder
  ROLE_PATTERNS = [
    [/研究|科学|分析|計算|math|science|research|analysis|comput/i, "研究・分析寄り"],
    [/編集|執筆|メディア|取材|writing|editor|media|journal|story|author/i, "編集・発信寄り"],
    [/教育|学習|コミュニティ|地域|civic|community|education|mentor|organizer/i, "教育・コミュニティ寄り"],
    [/事業|経営|戦略|プロダクト|startup|business|company|product|strategy/i, "事業・プロダクト寄り"],
    [/政策|行政|公共|policy|government|public/i, "政策・公共寄り"],
    [/デザイン|表現|アート|creative|design|visual|art/i, "表現・デザイン寄り"]
  ].freeze

  PALETTES = %w[atlas ember moss tide dusk].freeze
  MOTIFS = %w[orbit stack signal grid flare].freeze

  def initialize(person:, resolved_profile:, navigation_lens:)
    @person = person
    @resolved_profile = resolved_profile || {}
    @navigation_lens = navigation_lens || {}
  end

  def build
    roles = role_estimates
    themes = theme_estimates
    network_position = network_position_estimate
    approach = approach_estimate

    {
      notice: "公開情報と関係データからの補助表示です。性格や年収などの私的属性は推定しません。",
      roles: roles,
      themes: themes,
      network_position: network_position,
      approach: approach,
      evidence: evidence_points,
      persona_sketch: persona_sketch(roles:, themes:, network_position:, approach:)
    }
  end

  private

  def role_estimates
    roles = []
    title = primary_affiliation_title
    roles << title if title.present?

    ROLE_PATTERNS.each do |pattern, label|
      roles << label if source_text.match?(pattern)
    end

    dedupe(roles).first(4)
  end

  def theme_estimates
    dedupe(local_tags + remote_tags + organization_names).first(6)
  end

  def network_position_estimate
    bridge_count = Array(@navigation_lens[:bridge_people]).size
    primary_count = Array(@navigation_lens[:primary_people]).size
    case_count = Array(@navigation_lens[:related_cases]).size

    if bridge_count.positive?
      {
        label: "橋渡し型",
        reason: "異分野の接点が見えていて、関係網を横に広げる役割が強めです。"
      }
    elsif case_count >= 2
      {
        label: "事例蓄積型",
        reason: "公開されている事例が複数あり、実践の蓄積から人物像を読めます。"
      }
    elsif primary_count >= 2
      {
        label: "近接ネットワーク型",
        reason: "近い関係者が複数いるので、専門やテーマの近接圏で輪郭をつかみやすいです。"
      }
    else
      {
        label: "単独探索型",
        reason: "まだ接点データが少ないため、個別プロフィールから補って読む段階です。"
      }
    end
  end

  def approach_estimate
    if @person.fit_modes_list.any?
      {
        label: @person.fit_modes_list.first(2).join(" / "),
        reason: "人物メモに明示された用途から入るのが自然です。"
      }
    elsif @person.recommended_for.present?
      {
        label: truncate_text(@person.recommended_for),
        reason: "ローカル補足の役立つ文脈から話題を作れます。"
      }
    elsif theme_estimates.any?
      {
        label: theme_estimates.first(2).join(" / "),
        reason: "テーマや所属の共通項から入ると会話の入口を作りやすいです。"
      }
    else
      {
        label: "公開情報を追加中",
        reason: "まずは人物概要と関連事例から手がかりを増やす段階です。"
      }
    end
  end

  def persona_sketch(roles:, themes:, network_position:, approach:)
    {
      notice: "公開情報から着想した補助的な人物像です。性格や私生活を断定せず、仕事上の印象を読むための仮説スケッチとして使います。",
      title: "#{persona_title_prefix(roles)}#{network_position[:label]}",
      summary: persona_summary(roles:, themes:, network_position:),
      work_style: work_style_estimate(roles),
      interaction_style: interaction_style_estimate(network_position),
      momentum: momentum_estimate(approach),
      visual: portrait_visual(themes)
    }
  end

  def persona_title_prefix(roles)
    role = dominant_role_label(roles)

    case role
    when /研究|分析|Researcher/i
      "深掘りして渡す"
    when /編集|発信|editor|writer|journal/i
      "整理して届ける"
    when /教育|コミュニティ|mentor|organizer/i
      "場をひらいてつなぐ"
    when /事業|プロダクト|business|product/i
      "実装へ押し出す"
    when /政策|公共|policy|government/i
      "制度へ翻訳する"
    when /表現|デザイン|creative|design/i
      "表現で輪郭を作る"
    else
      "文脈を編み直す"
    end
  end

  def persona_summary(roles:, themes:, network_position:)
    theme_copy = themes.first(2).presence&.join(" / ") || "プロフィールと関係データ"

    "#{theme_copy}を軸に動く人物として読みやすく、#{network_position[:reason]}"
  end

  def work_style_estimate(roles)
    role = dominant_role_label(roles)

    case role
    when /研究|分析|Researcher/i
      {
        label: "深掘りして整理する",
        reason: "論点を掘ってから共有する進め方がはまりやすい人物像です。"
      }
    when /編集|発信|editor|writer|journal/i
      {
        label: "編集して伝える",
        reason: "散らばった情報を言葉や企画にまとめる力が出やすいです。"
      }
    when /教育|コミュニティ|mentor|organizer/i
      {
        label: "対話から場を育てる",
        reason: "一方的に押すより、対話しながら関係を育てる形が自然です。"
      }
    when /事業|プロダクト|business|product/i
      {
        label: "実装に寄せて進める",
        reason: "話をまとめるだけでなく、次の具体行動へ押し出す向きがあります。"
      }
    when /政策|公共|policy|government/i
      {
        label: "制度や文脈に翻訳する",
        reason: "個別の知見を公共的な論点へ載せ替える読み方が合います。"
      }
    when /表現|デザイン|creative|design/i
      {
        label: "形にして印象を残す",
        reason: "視覚や表現の切り口から理解を進める役割が強めです。"
      }
    else
      {
        label: "情報を集めて輪郭を作る",
        reason: "まだ情報量は多くなくても、断片を結んで読み解く人物像です。"
      }
    end
  end

  def interaction_style_estimate(network_position)
    case network_position[:label]
    when "橋渡し型"
      {
        label: "異分野のあいだを往復する",
        reason: "近い人だけでなく、少し離れた領域同士をつなぐと価値が出やすいです。"
      }
    when "事例蓄積型"
      {
        label: "実践ベースで信頼を作る",
        reason: "事例を起点に話すと、人物像と役割が伝わりやすくなります。"
      }
    when "近接ネットワーク型"
      {
        label: "近い専門圏で連携する",
        reason: "専門やテーマが近い相手と組ませると輪郭が早く見えます。"
      }
    else
      {
        label: "一点ずつ関係を育てる",
        reason: "広くつながるより、個別の接点から理解を深める段階です。"
      }
    end
  end

  def momentum_estimate(approach)
    label = approach[:label].to_s

    case label
    when /登壇|取材/
      {
        label: "公開発信で広がる",
        reason: "人前やメディアの場に出したときに価値が見えやすい人物像です。"
      }
    when /共同研究/
      {
        label: "少人数で深く進む",
        reason: "広い告知より、少人数の共同作業から強い成果が出やすいです。"
      }
    when /相談/
      {
        label: "一対一の相談から動く",
        reason: "公開の場より、個別の対話から本領が見えやすいです。"
      }
    when /公開情報を追加中/
      {
        label: "資料を増やしながら育てる",
        reason: "今は人物像を固定せず、情報を増やしながら解像度を上げる段階です。"
      }
    else
      {
        label: "テーマ起点で話が動く",
        reason: "明確なテーマや企画から入ると関係が立ち上がりやすいです。"
      }
    end
  end

  def portrait_visual(themes)
    seed = portrait_seed

    {
      initials: display_initials,
      palette: PALETTES[seed % PALETTES.length],
      motif: MOTIFS[seed % MOTIFS.length],
      orbit_labels: themes.first(3)
    }
  end

  def evidence_points
    points = []
    points << "タグ: #{dedupe(local_tags + remote_tags).first(3).join(' / ')}" if (local_tags + remote_tags).any?
    points << "所属: #{organization_names.first(2).join(' / ')}" if organization_names.any?
    points << "用途メモ: #{@person.fit_modes_list.first(2).join(' / ')}" if @person.fit_modes_list.any?

    related_case_titles = Array(@navigation_lens[:related_cases]).filter_map do |entry|
      entry.dig(:encounter_case)&.title
    end
    points << "関連事例: #{related_case_titles.first(2).join(' / ')}" if related_case_titles.any?

    related_people = Array(@navigation_lens[:primary_people]).filter_map { |entry| entry[:label] }
    points << "主要関係者: #{related_people.first(2).join(' / ')}" if related_people.any?

    points.first(4)
  end

  def primary_affiliation_title
    local_title = @person.primary_affiliation&.title.to_s.strip
    return local_title if local_title.present?

    Array(@resolved_profile[:affiliations]).filter_map do |affiliation|
      affiliation[:title] || affiliation["title"]
    end.find(&:present?)
  end

  def local_tags
    @person.tags.map(&:name)
  end

  def remote_tags
    Array(@resolved_profile[:tags])
  end

  def organization_names
    local_names = @person.organizations.map(&:name)
    remote_names = Array(@resolved_profile[:affiliations]).filter_map do |affiliation|
      affiliation[:name] || affiliation["name"]
    end

    dedupe(local_names + remote_names)
  end

  def source_text
    [
      @person.summary,
      @person.bio,
      @person.recommended_for,
      @person.meeting_value,
      @person.fit_modes,
      @person.introduction_note,
      @resolved_profile[:summary],
      @resolved_profile[:bio],
      local_tags,
      remote_tags,
      organization_names,
      primary_affiliation_title
    ].flatten.compact.join(" ")
  end

  def dominant_role_label(roles)
    roles.find { |role| role.include?("寄り") } || roles.first.to_s
  end

  def portrait_seed
    [@person.display_name.to_s, source_text].join.each_codepoint.sum
  end

  def display_initials
    tokens = @person.display_name.to_s.split.filter_map do |part|
      part.scan(/\X/).first
    end

    picked = if tokens.size >= 2
      tokens.first(2).join
    else
      @person.display_name.to_s.gsub(/\s+/, "").scan(/\X/).first(2).join
    end

    picked.present? ? picked.upcase : "?"
  end

  def dedupe(values)
    seen = {}

    Array(values).filter_map do |value|
      term = value.to_s.squish
      next if term.blank?

      key = term.downcase
      next if seen[key]

      seen[key] = true
      term
    end
  end

  def truncate_text(value, length: 36)
    text = value.to_s.squish
    return text if text.length <= length

    "#{text.first(length)}…"
  end
end
