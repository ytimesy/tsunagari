module ApplicationHelper
  CLUSTER_CATEGORY_PALETTE = {
    "organization" => { accent: "#3276d3", fill: "rgba(220, 234, 252, 0.94)", text: "#214f92", halo: "rgba(50, 118, 211, 0.18)" },
    "tag" => { accent: "#3f8f5b", fill: "rgba(224, 241, 229, 0.94)", text: "#2d6641", halo: "rgba(63, 143, 91, 0.18)" },
    "network" => { accent: "#d08b33", fill: "rgba(248, 234, 210, 0.94)", text: "#925c1a", halo: "rgba(208, 139, 51, 0.2)" },
    "other" => { accent: "#7b8797", fill: "rgba(232, 236, 241, 0.94)", text: "#536071", halo: "rgba(123, 135, 151, 0.18)" }
  }.freeze

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

  def cluster_category_palette
    CLUSTER_CATEGORY_PALETTE
  end

  def cluster_category_label(category)
    {
      "organization" => "所属クラスタ",
      "tag" => "分野クラスタ",
      "network" => "近縁クラスタ",
      "other" => "補助クラスタ"
    }.fetch(category, category)
  end

  def cluster_category_description(category)
    {
      "organization" => "共通の所属や機関を軸にまとまる人物群です。",
      "tag" => "近い専門分野や関心でまとまる人物群です。",
      "network" => "所属やタグをまたいだ近縁ネットワークです。",
      "other" => "大きな塊に入らない補助的な人物群です。"
    }.fetch(category, category.to_s)
  end

  def cluster_category_css_vars(category)
    palette = cluster_category_palette.fetch(category.to_s, cluster_category_palette.fetch("other"))

    [
      "--cluster-category-accent: #{palette[:accent]}",
      "--cluster-category-fill: #{palette[:fill]}",
      "--cluster-category-text: #{palette[:text]}",
      "--cluster-category-halo: #{palette[:halo]}"
    ].join("; ")
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

  def enabled_external_source_labels
    ExternalPeople::ProviderRegistry.available_sources.map { |source_name| external_source_label(source_name) }
  end

  def enabled_external_source_names_text(separator: " / ")
    enabled_external_source_labels.join(separator)
  end

  def external_people_import_title(target_person: nil)
    base = enabled_external_source_names_text
    target_person.present? ? "#{base}で補う" : "外部データから人物を取り込む"
  end

  def external_people_import_description(target_person: nil)
    source_text = enabled_external_source_names_text(separator: " と ")

    if target_person.present?
      "「#{target_person.display_name}」を土台に、#{source_text} の公開データを紐付けます。候補を選ぶと、この人物ページに外部情報源と軽量プロフィール情報が追加されます。"
    else
      "#{source_text} の公開データベースから人物候補を探し、人物録に取り込みます。"
    end
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

  def people_sort_options
    [
      [ '名前順', 'name_asc' ],
      [ '更新順', 'recently_updated' ],
      [ '公開順', 'recently_published' ]
    ]
  end

  def source_filter_options
    [
      [ 'すべて', '' ],
      [ '外部ソースあり', 'external' ],
      [ 'ローカルのみ', 'local' ]
    ]
  end

  def encounter_case_sort_options
    [
      [ '新しい順', 'newest' ],
      [ '古い順', 'oldest' ],
      [ '更新順', 'recently_updated' ]
    ]
  end

  def role_label(role)
    {
      "editor" => "編集者",
      "admin" => "管理者"
    }.fetch(role, role)
  end
end
