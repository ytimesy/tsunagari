require 'json'

module ExternalPeople
  class SeedProfileImporter
    def self.import!(path:)
      new(path: path).import!
    end

    def initialize(path:)
      @path = Pathname(path)
    end

    def import!
      raise ExternalPeople::Error, 'seed データが見つかりません。' unless @path.exist?

      profiles = JSON.parse(@path.read)
      imported_count = 0
      existing_count = 0
      failed = []

      Array(profiles).each do |raw_profile|
        profile = raw_profile.deep_symbolize_keys
        already_registered = PersonExternalProfile.exists?(source_name: profile[:source_name], external_id: profile[:external_id])
        ExternalPeople::Importer.import!(profile: normalized_profile(profile))

        if already_registered
          existing_count += 1
        else
          imported_count += 1
        end
      rescue StandardError => error
        failed << { external_id: profile&.dig(:external_id), message: error.message }
      end

      {
        total: Array(profiles).length,
        imported_count: imported_count,
        existing_count: existing_count,
        failed: failed
      }
    end

    private

    def normalized_profile(profile)
      {
        source_name: profile[:source_name],
        external_id: profile[:external_id],
        source_url: profile[:source_url],
        fetched_at: Time.zone.parse(profile[:fetched_at].to_s).presence || Time.current,
        display_name: profile[:display_name],
        summary: profile[:summary],
        bio: profile[:bio],
        tags: Array(profile[:tags]),
        affiliations: Array(profile[:affiliations])
      }
    end
  end
end
