module RelationshipKindClassifier
  KINDS = {
    "same_field" => {
      label: "同分野",
      description: "共通する専門領域や関心でつながる関係"
    },
    "same_organization" => {
      label: "同所属",
      description: "同じ組織や場を共有している関係"
    },
    "co_creation" => {
      label: "共創",
      description: "同じ事例や成果を一緒に生み出す関係"
    },
    "succession" => {
      label: "継承",
      description: "知識、姿勢、流儀が受け継がれていく関係"
    },
    "inspiration" => {
      label: "触発",
      description: "出会いが転機や新しい視点を生む関係"
    },
    "crossing" => {
      label: "越境",
      description: "異分野や異文化をまたいで結びつく関係"
    },
    "support" => {
      label: "支援",
      description: "挑戦や成長を支え、前進を下支えする関係"
    },
    "sharpening" => {
      label: "切磋琢磨",
      description: "競争や緊張感が互いを高める関係"
    }
  }.freeze

  module_function

  def classify(shared_tags:, shared_organizations:, shared_case_count: 0, shared_outcome_directions: [], shared_insight_types: [], role_pairs: [], text_fragments: [])
    facts = {
      shared_tags: normalized_terms(shared_tags),
      shared_organizations: normalized_terms(shared_organizations),
      shared_case_count: shared_case_count.to_i,
      shared_outcome_directions: Array(shared_outcome_directions).map(&:to_s),
      shared_insight_types: Array(shared_insight_types).map(&:to_s),
      role_pairs: Array(role_pairs).map { |left_role, right_role| [ left_role.to_s, right_role.to_s ] },
      text_blob: Array(text_fragments).join(" ").downcase
    }

    kind = determine_kind(facts)

    {
      kind: kind,
      kind_label: KINDS.fetch(kind)[:label],
      kind_description: KINDS.fetch(kind)[:description],
      tone: tone_for(kind, facts),
      reason: reason_for(kind, facts)
    }
  end

  def label_for(kind)
    KINDS.fetch(kind.to_s, KINDS.fetch("same_field"))[:label]
  end

  def description_for(kind)
    KINDS.fetch(kind.to_s, KINDS.fetch("same_field"))[:description]
  end

  def options
    KINDS.map { |key, value| [ key, value[:label], value[:description] ] }
  end

  def determine_kind(facts)
    return "succession" if succession?(facts)
    return "support" if support?(facts)
    return "sharpening" if sharpening?(facts)
    return "inspiration" if inspiration?(facts)
    return "co_creation" if co_creation?(facts)
    return "crossing" if crossing?(facts)
    return "same_organization" if same_organization?(facts)
    return "same_field" if same_field?(facts)

    "same_field"
  end

  def tone_for(kind, facts)
    return RelationshipGraphBuilder::DIVERSE_TONE if %w[crossing sharpening].include?(kind)
    return RelationshipGraphBuilder::DIVERSE_TONE if kind == "inspiration" && facts[:shared_tags].empty? && facts[:shared_organizations].empty?

    if same_field?(facts) || same_organization?(facts) || %w[co_creation succession support].include?(kind)
      RelationshipGraphBuilder::SIMILAR_TONE
    else
      RelationshipGraphBuilder::DIVERSE_TONE
    end
  end

  def reason_for(kind, facts)
    reason_parts = [ "#{label_for(kind)}: #{description_for(kind)}" ]
    reason_parts << "共通所属: #{facts[:shared_organizations].first(2).join(', ')}" if facts[:shared_organizations].any?
    reason_parts << "共通タグ: #{facts[:shared_tags].first(2).join(', ')}" if facts[:shared_tags].any?
    reason_parts << "#{facts[:shared_case_count]}件の事例で接点" if facts[:shared_case_count].positive?
    reason_parts.join(" / ")
  end

  def same_field?(facts)
    facts[:shared_tags].any?
  end

  def same_organization?(facts)
    facts[:shared_organizations].any?
  end

  def co_creation?(facts)
    return false unless facts[:shared_case_count].positive?
    return false if facts[:shared_tags].empty? && facts[:shared_organizations].empty? && bridge_role?(facts[:role_pairs])

    facts[:shared_outcome_directions].any? { |direction| %w[positive mixed].include?(direction) } ||
      facts[:shared_insight_types].include?("enabler") ||
      facts[:shared_case_count] >= 2 ||
      keyword_match?(facts[:text_blob], co_creation_keywords)
  end

  def inspiration?(facts)
    facts[:shared_insight_types].include?("turning_point") || keyword_match?(facts[:text_blob], inspiration_keywords)
  end

  def crossing?(facts)
    keyword_match?(facts[:text_blob], crossing_keywords) ||
      bridge_role?(facts[:role_pairs]) ||
      (facts[:shared_case_count].positive? && facts[:shared_tags].empty? && facts[:shared_organizations].empty?)
  end

  def support?(facts)
    keyword_match?(facts[:text_blob], support_keywords) || support_role?(facts[:role_pairs])
  end

  def succession?(facts)
    keyword_match?(facts[:text_blob], succession_keywords) || succession_role?(facts[:role_pairs])
  end

  def sharpening?(facts)
    keyword_match?(facts[:text_blob], sharpening_keywords)
  end

  def support_role?(role_pairs)
    role_pairs.any? do |left_role, right_role|
      role_supportive?(left_role) || role_supportive?(right_role)
    end
  end

  def succession_role?(role_pairs)
    role_pairs.any? do |left_role, right_role|
      role_mentoring?(left_role) || role_mentoring?(right_role)
    end
  end

  def bridge_role?(role_pairs)
    role_pairs.any? do |left_role, right_role|
      role_bridging?(left_role) || role_bridging?(right_role)
    end
  end

  def role_supportive?(role)
    role.to_s.match?(/support|sponsor|host|backer|patron|fund|advisor|supporter|支援|助成|後援|伴走/)
  end

  def role_mentoring?(role)
    role.to_s.match?(/mentor|teacher|advisor|guide|master|師|弟子|後継/)
  end

  def role_bridging?(role)
    role.to_s.match?(/bridge|translator|connector|liaison|媒介|橋渡し|越境/)
  end

  def keyword_match?(text_blob, keywords)
    keywords.any? { |keyword| text_blob.include?(keyword) }
  end

  def normalized_terms(values)
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

  def succession_keywords
    %w[succession mentor mentored student apprentice disciple lineage legacy inherit inherited tutelage 継承 師弟 弟子 師匠 門下 後継]
  end

  def support_keywords
    %w[support supported supporting sponsor sponsored funding grant donor patron backed backing ally help helped 助成 支援 援助 後押し 後援 資金]
  end

  def sharpening_keywords
    %w[rival rivalry challenge challenged debate debated critique critiqued competition competitive contest sparring tension 切磋琢磨 論争 競争 批評]
  end

  def inspiration_keywords
    %w[inspire inspired inspiration trigger triggered sparked catalyst catalyzed turning point influenced 触発 きっかけ 転機 刺激 影響]
  end

  def crossing_keywords
    %w[cross-sector crossdisciplinary cross-disciplinary interdisciplinary inter-disciplinary bridge bridging connector liaison boundary-spanning 越境 異分野 異業種 異文化 横断 橋渡し]
  end

  def co_creation_keywords
    %w[co-create cocreate co-created build built create created launch launched found founded collaboration collaborated project venture invention research 共創 共同 立ち上げ 創業 研究 開発]
  end
end
