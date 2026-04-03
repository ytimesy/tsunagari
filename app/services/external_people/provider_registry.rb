module ExternalPeople
  module ProviderRegistry
    module_function

    def available_sources
      TsunagariFeatureFlags.external_people_sources
    end

    def provider_for(source_name)
      source_name = source_name.to_s

      case source_name
      when "wikidata"
        WikidataClient
      when "openalex"
        raise ExternalPeople::Error, "OpenAlex は現在無効です。" unless TsunagariFeatureFlags.openalex_enabled?

        OpenAlexClient
      else
        raise ExternalPeople::Error, "未対応のデータソースです。"
      end
    end
  end
end
