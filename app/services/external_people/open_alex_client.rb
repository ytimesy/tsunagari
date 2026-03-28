module ExternalPeople
  class OpenAlexClient < BaseClient
    AUTHORS_ENDPOINT = "https://api.openalex.org/authors".freeze

    class << self
      delegate :search, :fetch_profile, :fetch_top_people, :search_profiles, to: :new
    end

    def search(query)
      json = fetch_json(AUTHORS_ENDPOINT, params: {
        search: query,
        "per-page": 8
      })

      Array(json["results"]).map do |result|
        {
          source_name: "openalex",
          external_id: extract_openalex_id(result["id"]),
          display_name: result["display_name"],
          subtitle: search_subtitle(result),
          badges: [ "OpenAlex", works_badge(result["works_count"]) ].compact,
          source_url: result["id"]
        }
      end
    end

    def fetch_profile(external_id)
      json = fetch_json("#{AUTHORS_ENDPOINT}/#{external_id}")
      normalize_profile(json, external_id: external_id)
    end

    def fetch_top_people(limit: 100)
      json = fetch_json(AUTHORS_ENDPOINT, params: {
        sort: "cited_by_count:desc",
        "per-page": limit.to_i.clamp(1, 200)
      })

      Array(json["results"]).map do |result|
        normalize_profile(result, external_id: extract_openalex_id(result["id"]))
      end
    end

    def search_profiles(query, limit: 12)
      json = fetch_json(AUTHORS_ENDPOINT, params: {
        search: query,
        "per-page": limit.to_i.clamp(1, 50)
      })

      Array(json["results"]).map do |result|
        normalize_profile(result, external_id: extract_openalex_id(result["id"]))
      end
    end

    private

    def normalize_profile(json, external_id:)
      display_name = json["display_name"].to_s
      alternatives = Array(json["display_name_alternatives"]).first(4)
      affiliations = extract_affiliations(json)
      tags = extract_tags(json)

      summary_parts = []
      summary_parts << affiliations.first[:name] if affiliations.first
      summary_parts << "#{json["works_count"]} works" if json["works_count"].present?
      summary_parts << "#{json["cited_by_count"]} citations" if json["cited_by_count"].present?

      bio_parts = []
      bio_parts << summary_parts.join(" / ") if summary_parts.any?
      bio_parts << "別表記: #{alternatives.join(' / ')}" if alternatives.any?
      bio_parts << "ORCID: #{json["orcid"]}" if json["orcid"].present?

      {
        source_name: "openalex",
        external_id: external_id,
        source_url: json["id"],
        fetched_at: Time.current,
        display_name: display_name,
        summary: summary_parts.join(" / "),
        bio: bio_parts.join("\n"),
        tags: tags,
        affiliations: affiliations
      }
    end

    def extract_openalex_id(identifier)
      identifier.to_s.split("/").last
    end

    def search_subtitle(result)
      institution = Array(result["last_known_institutions"]).first || Array(result["affiliations"]).first&.[]("institution")
      [ institution&.[]("display_name"), result["orcid"] ].compact.join(" / ").presence || "OpenAlex author"
    end

    def works_badge(count)
      return if count.blank?

      "#{count} works"
    end

    def extract_tags(json)
      Array(json["x_concepts"]).sort_by { |concept| -concept["score"].to_f }
                              .filter_map { |concept| concept["display_name"].presence }
                              .first(6)
    end

    def extract_affiliations(json)
      institutions = Array(json["last_known_institutions"]).presence ||
        Array(json["affiliations"]).filter_map { |affiliation| affiliation["institution"] }

      institutions.filter_map do |institution|
        name = institution["display_name"].presence
        next unless name

        {
          name: name,
          category: "institution",
          website_url: institution["homepage_url"].presence
        }
      end.uniq { |affiliation| affiliation[:name] }
    end
  end
end
