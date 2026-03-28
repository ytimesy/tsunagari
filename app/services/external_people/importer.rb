module ExternalPeople
  class Importer
    def self.import!(profile:, target_person: nil)
      new(profile: profile, target_person: target_person).import!
    end

    def self.graph_tags_from(profile)
      self.normalize_terms(Array(self.extract_value(profile, :tags)), limit: 8)
    end

    def self.graph_organizations_from(profile)
      organizations = Array(self.extract_value(profile, :affiliations)).filter_map do |affiliation|
        next self.normalize_term(affiliation) unless affiliation.respond_to?(:[])

        self.normalize_term(affiliation[:name] || affiliation["name"])
      end

      self.normalize_terms(organizations, limit: 6)
    end

    def self.extract_value(profile, key)
      return profile[key] if profile.respond_to?(:[]) && profile[key].present?

      profile[key.to_s] if profile.respond_to?(:[])
    end

    def self.normalize_terms(values, limit:)
      seen = {}

      Array(values).filter_map do |value|
        normalized = normalize_term(value)
        next if normalized.blank?

        key = normalized.downcase
        next if seen[key]

        seen[key] = true
        normalized
      end.first(limit)
    end

    def self.normalize_term(value)
      term = value.to_s.squish
      term.presence
    end

    def initialize(profile:, target_person: nil)
      @profile = profile.deep_symbolize_keys
      @target_person = target_person
    end

    def import!
      external_profile = PersonExternalProfile.find_or_initialize_by(
        source_name: @profile[:source_name],
        external_id: @profile[:external_id]
      )

      if external_profile.person.present? && @target_person.present? && external_profile.person != @target_person
        raise ExternalPeople::Error, "この外部データは別の人物に紐づいています。"
      end

      person = @target_person || external_profile.person || Person.new(publication_status: "draft")
      assign_person_fields(person)

      ActiveRecord::Base.transaction do
        person.save!
        save_external_profile(external_profile, person)
      end

      person
    end

    private

    def assign_person_fields(person)
      person.display_name = @profile[:display_name] if person.display_name.blank?
      person.published_at ||= Time.current if person.publication_status == "published"
    end

    def save_external_profile(external_profile, person)
      external_profile.person = person
      external_profile.source_url = @profile[:source_url]
      external_profile.fetched_at = @profile[:fetched_at] || Time.current
      external_profile.graph_tags = self.class.graph_tags_from(@profile)
      external_profile.graph_organizations = self.class.graph_organizations_from(@profile)
      external_profile.save!
    end

  end
end
