module ExternalPeople
  class WikidataSampleClient < BaseClient
    ENDPOINT = "https://query.wikidata.org/sparql".freeze

    class << self
      delegate :fetch_people, to: :new
    end

    def fetch_people(limit: 100)
      json = fetch_json(ENDPOINT, params: { format: "json", query: query_for(limit) })

      Array(json.dig("results", "bindings")).filter_map do |binding|
        display_name = binding.dig("personLabel", "value").to_s.strip
        next if display_name.blank?

        occupations = split_pipe_values(binding.dig("occupations", "value"))
        employers = split_pipe_values(binding.dig("employers", "value"))
        summary = binding.dig("description", "value").presence || occupations.first.to_s

        {
          source_name: "wikidata",
          external_id: extract_qid(binding.dig("person", "value")),
          source_url: binding.dig("person", "value"),
          fetched_at: Time.current,
          display_name: display_name,
          summary: summary,
          bio: build_bio(summary: summary, occupations: occupations, employers: employers),
          tags: occupations.first(6),
          affiliations: employers.first(3).map { |name| { name: name, category: "organization" } },
          raw_payload: {
            description: summary,
            occupations: occupations,
            employers: employers
          }
        }
      end
    end

    private

    def query_for(limit)
      <<~SPARQL
        PREFIX wd: <http://www.wikidata.org/entity/>
        PREFIX wdt: <http://www.wikidata.org/prop/direct/>
        PREFIX wikibase: <http://wikiba.se/ontology#>
        PREFIX schema: <http://schema.org/>
        PREFIX bd: <http://www.bigdata.com/rdf#>

        SELECT ?person ?personLabel
               (SAMPLE(?description) AS ?description)
               (GROUP_CONCAT(DISTINCT ?occupationLabel; separator="|") AS ?occupations)
               (GROUP_CONCAT(DISTINCT ?employerLabel; separator="|") AS ?employers)
        WHERE {
          ?person wdt:P31 wd:Q5 ;
                  wikibase:sitelinks ?sitelinks .
          FILTER(?sitelinks > 45)

          OPTIONAL {
            ?person schema:description ?description .
            FILTER(LANG(?description) IN ("ja", "en"))
          }

          OPTIONAL { ?person wdt:P106 ?occupation . }
          OPTIONAL { ?person wdt:P108 ?employer . }

          SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
        }
        GROUP BY ?person ?personLabel ?sitelinks
        ORDER BY DESC(?sitelinks)
        LIMIT #{limit.to_i.clamp(1, 200)}
      SPARQL
    end

    def split_pipe_values(value)
      value.to_s.split("|").map(&:strip).reject(&:blank?).uniq
    end

    def extract_qid(url)
      url.to_s.split("/").last
    end

    def build_bio(summary:, occupations:, employers:)
      sections = []
      sections << summary if summary.present?
      sections << "職業: #{occupations.join(', ')}" if occupations.any?
      sections << "所属候補: #{employers.join(', ')}" if employers.any?
      sections.join("\n")
    end
  end
end
