class TsunagariFeatureFlags
  class << self
    def openalex_enabled?
      raw_value = ENV["TSUNAGARI_OPENALEX_ENABLED"]
      return !Rails.env.production? if raw_value.nil?

      ActiveModel::Type::Boolean.new.cast(raw_value)
    end

    def external_people_sources
      sources = ["wikidata"]
      sources << "openalex" if openalex_enabled?
      sources
    end
  end
end
