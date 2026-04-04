class PersonPublicEstimateBuilder
  ROLE_PATTERNS = [
    [/研究|科学|分析|計算|math|science|research|analysis|comput/i, "研究・分析寄り"],
    [/編集|執筆|メディア|取材|writing|editor|media|journal|story|author/i, "編集・発信寄り"],
    [/教育|学習|コミュニティ|地域|civic|community|education|mentor|organizer/i, "教育・コミュニティ寄り"],
    [/事業|経営|戦略|プロダクト|startup|business|company|product|strategy/i, "事業・プロダクト寄り"],
    [/政策|行政|公共|policy|government|public/i, "政策・公共寄り"],
    [/デザイン|表現|アート|creative|design|visual|art/i, "表現・デザイン寄り"]
  ].freeze

  def initialize(person:, resolved_profile:, navigation_lens:)
    @person = person
    @resolved_profile = resolved_profile || {}
    @navigation_lens = navigation_lens || {}
  end

  def build
    {
      notice: "公開情報と関係データからの補助表示です。性格や年収などの私的属性は推定しません。",
      roles: role_estimates,
      themes: theme_estimates,
      network_position: network_position_estimate,
      approach: approach_estimate,
      evidence: evidence_points
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
