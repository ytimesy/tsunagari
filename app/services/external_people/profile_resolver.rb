require_dependency Rails.root.join("app/services/external_people/error").to_s
require_dependency Rails.root.join("app/services/external_people/provider_registry").to_s
require_dependency Rails.root.join("app/services/external_people/wikidata_client").to_s
require_dependency Rails.root.join("app/services/external_people/open_alex_client").to_s

module ExternalPeople
  class ProfileResolver
    def initialize
      @cache = {}
    end

    def resolve(person)
      @cache[person.id] ||= build_profile(person)
    end

    def resolve_many(people)
      Array(people).compact.index_with { |person| resolve(person) }
    end

    def metadata_index_for(people)
      Array(people).compact.each_with_object({}) do |person, index|
        profile = resolve(person)

        index[person.id] = {
          tags: profile[:tags],
          organizations: profile[:affiliations].map { |affiliation| affiliation[:name] }
        }
      end
    end

    private

    def build_profile(person)
      remote_profile = fetch_remote_profile(person)
      local_affiliations = person.person_affiliations.includes(:organization).map do |affiliation|
        {
          name: affiliation.organization.name,
          category: affiliation.organization.category,
          website_url: affiliation.organization.website_url,
          title: affiliation.title
        }
      end

      {
        display_name: person.display_name.presence || remote_profile&.dig(:display_name) || "名称未設定",
        summary: person.summary.presence || remote_profile&.dig(:summary).presence,
        bio: person.bio.presence || remote_profile&.dig(:bio).presence,
        tags: person.tags.any? ? person.tags.order(:name).pluck(:name) : Array(remote_profile&.dig(:tags)),
        affiliations: local_affiliations.presence || Array(remote_profile&.dig(:affiliations)),
        source_mode: source_mode(person, remote_profile),
        source_error: @errors && @errors[person.id],
        external_profile: person.primary_external_profile
      }
    end

    def fetch_remote_profile(person)
      external_profile = person.primary_external_profile
      return unless external_profile

      Rails.cache.fetch(cache_key_for(external_profile), expires_in: 12.hours) do
        ProviderRegistry.provider_for(external_profile.source_name).fetch_profile(external_profile.external_id).deep_symbolize_keys
      end
    rescue ExternalPeople::Error => error
      @errors ||= {}
      @errors[person.id] = error.message
      nil
    end

    def source_mode(person, remote_profile)
      return "live" if remote_profile.present?
      return "linked" if person.primary_external_profile.present?

      "local"
    end

    def cache_key_for(external_profile)
      [
        "external-people-profile",
        external_profile.source_name,
        external_profile.external_id
      ].join(":")
    end
  end
end
