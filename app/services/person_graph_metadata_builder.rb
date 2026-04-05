class PersonGraphMetadataBuilder
  FIT_MODE_HINTS = {
    "登壇向き" => /登壇|講演|スピーカー|配信|話す/,
    "取材向き" => /取材|インタビュー|記事|報道/,
    "共同研究向き" => /共同研究|研究協力|コラボ/,
    "相談向き" => /相談|壁打ち|助言|メンタリング/
  }.freeze
  ASCII_ONLY_PATTERN = /\A[[:ascii:][:alnum:]_+.-]+\z/
  TEXT_ATTRIBUTES = %i[summary bio recommended_for meeting_value introduction_note].freeze

  def self.build(person, profile_metadata: {})
    new(person, profile_metadata: profile_metadata).build
  end

  def initialize(person, profile_metadata: {})
    @person = person
    @profile_metadata = profile_metadata || {}
  end

  def build
    {
      tags: normalized_terms(local_tags + inferred_quality_tags + Array(@profile_metadata[:tags])),
      organizations: normalized_terms(local_organizations + Array(@profile_metadata[:organizations])),
      source_names: @person.person_external_profiles.map(&:source_name).compact.uniq
    }
  end

  def graph_ready?
    metadata = build
    metadata[:tags].any? || metadata[:organizations].any?
  end

  private

  def local_tags
    @local_tags ||= @person.tags.map(&:name) +
      @person.fit_modes_list +
      @person.person_external_profiles.flat_map(&:cached_graph_tags)
  end

  def local_organizations
    @local_organizations ||= @person.organizations.map(&:name) +
      @person.person_external_profiles.flat_map(&:cached_graph_organizations)
  end

  def inferred_quality_tags
    (matched_representative_fields + matched_fit_mode_hints).uniq.first(8)
  end

  def matched_representative_fields
    text = quality_text
    return [] if text.blank?

    RepresentativeFieldCatalog.field_names.select do |field_name|
      field_matches?(text, field_name)
    end
  end

  def matched_fit_mode_hints
    text = quality_text
    return [] if text.blank?

    FIT_MODE_HINTS.filter_map do |label, pattern|
      label if text.match?(pattern)
    end
  end

  def field_matches?(text, field_name)
    if field_name.match?(ASCII_ONLY_PATTERN)
      text.match?(ascii_field_pattern(field_name))
    else
      text.include?(field_name)
    end
  end

  def ascii_field_pattern(field_name)
    escaped = Regexp.escape(field_name)
    /(^|[^[:alnum:]])#{escaped}([^[:alnum:]]|$)|#{escaped}(?=[ぁ-んァ-ヶ一-龠])/i
  end

  def quality_text
    @quality_text ||= TEXT_ATTRIBUTES.filter_map do |attribute_name|
      @person.public_send(attribute_name).to_s.squish.presence
    end.join("\n")
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
end
