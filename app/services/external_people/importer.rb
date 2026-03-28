module ExternalPeople
  class Importer
    def self.import!(profile:, target_person: nil)
      new(profile: profile, target_person: target_person).import!
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
        merge_tags(person)
        merge_affiliations(person)
        save_external_profile(external_profile, person)
      end

      person
    end

    private

    def assign_person_fields(person)
      person.display_name = @profile[:display_name] if person.display_name.blank?
      person.summary = @profile[:summary] if person.summary.blank?
      person.bio = @profile[:bio] if person.bio.blank?
      person.published_at ||= Time.current if person.publication_status == "published"
    end

    def merge_tags(person)
      tag_names = Array(@profile[:tags]).map { |tag| tag.to_s.strip }.reject(&:blank?).uniq
      return if tag_names.empty?

      imported_tags = tag_names.map do |name|
        Tag.find_or_initialize_by(normalized_name: name.downcase).tap do |tag|
          tag.name = name
          tag.save! if tag.new_record? || tag.changed?
        end
      end

      person.tags = (person.tags.to_a + imported_tags).uniq { |tag| tag.id || tag.normalized_name }
    end

    def merge_affiliations(person)
      return if Array(@profile[:affiliations]).empty?

      Array(@profile[:affiliations]).each_with_index do |affiliation, index|
        name = affiliation[:name].to_s.strip
        next if name.blank?

        organization = Organization.find_or_initialize_by(slug: Organization.slug_candidate(name))
        organization.name = name
        organization.category = affiliation[:category].presence || organization.category
        organization.website_url = affiliation[:website_url].presence || organization.website_url
        organization.save!

        person.person_affiliations.find_or_create_by!(
          organization: organization,
          title: affiliation[:title].presence,
          started_on: affiliation[:started_on]
        ) do |record|
          record.primary_flag = person.primary_affiliation.blank? && index.zero?
          record.ended_on = affiliation[:ended_on]
        end
      end
    end

    def save_external_profile(external_profile, person)
      external_profile.person = person
      external_profile.source_url = @profile[:source_url]
      external_profile.raw_payload = @profile[:raw_payload] || {}
      external_profile.fetched_at = @profile[:fetched_at] || Time.current
      external_profile.save!
    end
  end
end
