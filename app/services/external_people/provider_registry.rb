module ExternalPeople
  module ProviderRegistry
    module_function

    def provider_for(source_name)
      case source_name.to_s
      when "wikidata" then WikidataClient
      when "openalex" then OpenAlexClient
      else
        raise ExternalPeople::Error, "未対応のデータソースです。"
      end
    end
  end
end
