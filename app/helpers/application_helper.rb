module ApplicationHelper
  RELATIONSHIP_KIND_PALETTE = {
    "same_field" => { stroke: "#4b84b6", fill: "rgba(220, 235, 248, 0.92)", text: "#365f89" },
    "same_organization" => { stroke: "#5f8f5a", fill: "rgba(225, 240, 221, 0.94)", text: "#456640" },
    "co_creation" => { stroke: "#4e9b8c", fill: "rgba(218, 242, 236, 0.92)", text: "#2f6d63" },
    "support" => { stroke: "#7aa35b", fill: "rgba(230, 242, 215, 0.94)", text: "#55763d" },
    "succession" => { stroke: "#7d74ab", fill: "rgba(232, 228, 246, 0.92)", text: "#5b5384" },
    "crossing" => { stroke: "#cda43d", fill: "rgba(246, 233, 188, 0.92)", text: "#8b6a1f" },
    "inspiration" => { stroke: "#d07a5c", fill: "rgba(248, 230, 220, 0.94)", text: "#98543a" },
    "sharpening" => { stroke: "#b6677c", fill: "rgba(244, 224, 231, 0.94)", text: "#834556" }
  }.freeze

  def publication_status_label(status)
    {
      "draft" => "下書き",
      "review" => "レビュー中",
      "published" => "公開中",
      "archived" => "アーカイブ"
    }.fetch(status, status)
  end

  def evidence_level_label(level)
    {
      "documented" => "資料確認済み",
      "reported" => "報告ベース",
      "observed" => "観察ベース",
      "hypothesis" => "仮説"
    }.fetch(level, level)
  end

  def outcome_direction_label(direction)
    {
      "positive" => "前進",
      "negative" => "失敗・後退",
      "mixed" => "混合",
      "unresolved" => "未解決"
    }.fetch(direction, direction)
  end

  def insight_type_label(insight_type)
    {
      "enabler" => "前進要因",
      "barrier" => "阻害要因",
      "lesson" => "学び",
      "turning_point" => "転機"
    }.fetch(insight_type, insight_type)
  end

  def relationship_tone_label(tone)
    {
      "similar" => "似たもの同士",
      "diverse" => "異質な組み合わせ"
    }.fetch(tone, tone)
  end

  def relationship_kind_label(kind)
    RelationshipKindClassifier.label_for(kind)
  end

  def relationship_kind_description(kind)
    RelationshipKindClassifier.description_for(kind)
  end

  def relationship_kind_options
    RelationshipKindClassifier.options
  end

  def relationship_kind_palette
    RELATIONSHIP_KIND_PALETTE
  end

  def browser_asset_version
    @browser_asset_version ||= begin
      asset_paths = %w[public/icon.png public/icon.svg].map { |path| Rails.root.join(path) }
      asset_paths.filter(&:exist?).map { |path| path.mtime.to_i }.max.to_s
    end
  end

  def manifest_href
    "/manifest.json?v=#{browser_asset_version}"
  end

  def icon_png_href
    "/icon.png?v=#{browser_asset_version}"
  end

  def icon_svg_href
    "/icon.svg?v=#{browser_asset_version}"
  end

  def relationship_kind_css_vars(kind)
    palette = relationship_kind_palette.fetch(kind.to_s, relationship_kind_palette.fetch("same_field"))

    [
      "--relationship-kind-stroke: #{palette[:stroke]}",
      "--relationship-kind-fill: #{palette[:fill]}",
      "--relationship-kind-text: #{palette[:text]}"
    ].join("; ")
  end

  def external_source_label(source_name)
    {
      "wikidata" => "Wikidata",
      "openalex" => "OpenAlex"
    }.fetch(source_name, source_name)
  end

  def external_profile_mode_label(mode)
    {
      "live" => "外部DBを都度参照中",
      "linked" => "外部DBに紐付いていますが、今回はローカル情報で表示中",
      "local" => "ローカル編集情報のみ"
    }.fetch(mode, mode)
  end

  def edit_history_action_label(action)
    {
      "created" => "作成",
      "updated" => "更新",
      "imported" => "取込"
    }.fetch(action, action)
  end

  def person_source_entries(person)
    entries = person.person_external_profiles.order(:source_name).map do |profile|
      {
        label: "#{external_source_label(profile.source_name)} / #{profile.external_id}",
        href: profile.source_url
      }
    end

    entries.presence || [ { label: "ローカル編集情報", href: nil } ]
  end

  def encounter_case_source_entries(encounter_case)
    entries = encounter_case.sources.map do |source|
      {
        label: source.title.presence || source.url,
        href: source.url
      }
    end

    entries.presence || [ { label: "出典未設定", href: nil } ]
  end

  def role_label(role)
    {
      "editor" => "編集者",
      "admin" => "管理者"
    }.fetch(role, role)
  end
end
