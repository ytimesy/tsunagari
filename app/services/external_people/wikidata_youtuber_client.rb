module ExternalPeople
  class WikidataYoutuberClient < BaseClient
    API_ENDPOINT = "https://www.wikidata.org/w/api.php".freeze
    HUMAN_QID = "Q5".freeze
    MAX_BATCH_SIZE = 50
    SEARCH_OPEN_TIMEOUT_SECONDS = 5
    SEARCH_READ_TIMEOUT_SECONDS = 20
    ENTITY_OPEN_TIMEOUT_SECONDS = 5
    ENTITY_READ_TIMEOUT_SECONDS = 20
    CREATOR_OCCUPATIONS = [
      { qid: "Q17125263", label: "YouTuber" },
      { qid: "Q4110598", label: "vlogger" },
      { qid: "Q57414145", label: "online streamer" },
      { qid: "Q109459317", label: "content creator" },
      { qid: "Q118371929", label: "web video producer" },
      { qid: "Q111263847", label: "digital creator" },
      { qid: "Q2045208", label: "internet celebrity" },
      { qid: "Q15077007", label: "podcaster" }
    ].freeze

    class << self
      delegate :fetch_people, to: :new
    end

    def fetch_people(occupation_qid:, occupation_label:, limit: 50, offset: 0)
      normalized_limit = limit.to_i.clamp(1, MAX_BATCH_SIZE)
      normalized_offset = [ offset.to_i, 0 ].max
      entity_ids = search_entity_ids(occupation_qid: occupation_qid, limit: normalized_limit, offset: normalized_offset)
      return [] if entity_ids.empty?

      entities = fetch_entity_summaries(entity_ids)

      entity_ids.filter_map do |entity_id|
        normalize_profile(entity_id, entities[entity_id], occupation_label: occupation_label)
      end
    end

    private

    def search_entity_ids(occupation_qid:, limit:, offset:)
      json = fetch_json(
        API_ENDPOINT,
        params: {
          action: "query",
          list: "search",
          srsearch: search_query_for(occupation_qid),
          srnamespace: 0,
          srlimit: limit,
          sroffset: offset,
          format: "json"
        },
        open_timeout: SEARCH_OPEN_TIMEOUT_SECONDS,
        read_timeout: SEARCH_READ_TIMEOUT_SECONDS
      )

      Array(json.dig("query", "search")).filter_map do |entry|
        title = entry["title"].to_s.strip
        title if title.match?(/\AQ\d+\z/)
      end
    end

    def fetch_entity_summaries(entity_ids)
      json = fetch_json(
        API_ENDPOINT,
        params: {
          action: "wbgetentities",
          ids: entity_ids.join("|"),
          props: "labels|descriptions",
          languages: "ja|en",
          format: "json"
        },
        open_timeout: ENTITY_OPEN_TIMEOUT_SECONDS,
        read_timeout: ENTITY_READ_TIMEOUT_SECONDS
      )

      json.fetch("entities", {})
    end

    def search_query_for(occupation_qid)
      "haswbstatement:P31=#{HUMAN_QID} haswbstatement:P106=#{occupation_qid}"
    end

    def normalize_profile(entity_id, entity, occupation_label:)
      return if entity.blank?

      display_name = extract_localized_text(entity["labels"]).presence || entity_id
      description = extract_localized_text(entity["descriptions"]).presence || occupation_label

      {
        source_name: "wikidata",
        external_id: entity_id,
        source_url: wikidata_url(entity_id),
        fetched_at: Time.current,
        display_name: display_name,
        summary: description,
        bio: description,
        tags: [ "YouTube", occupation_label ],
        affiliations: []
      }
    end

    def wikidata_url(entity_id)
      "https://www.wikidata.org/wiki/#{entity_id}"
    end
  end
end
