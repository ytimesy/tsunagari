module ExternalPeople
  class WikidataDiverseClient < BaseClient
    API_ENDPOINT = "https://www.wikidata.org/w/api.php".freeze
    HUMAN_QID = "Q5".freeze
    MAX_BATCH_SIZE = 25
    SEARCH_OPEN_TIMEOUT_SECONDS = 5
    SEARCH_READ_TIMEOUT_SECONDS = 20
    ENTITY_OPEN_TIMEOUT_SECONDS = 5
    ENTITY_READ_TIMEOUT_SECONDS = 20
    GENRE_PRESETS = [
      { key: "politics", label: "政治", occupations: [ { qid: "Q82955", label: "politician" } ] },
      { key: "law", label: "法律", occupations: [ { qid: "Q40348", label: "lawyer" } ] },
      { key: "business", label: "企業経営", occupations: [ { qid: "Q43845", label: "businessperson" } ] },
      { key: "science", label: "科学", occupations: [ { qid: "Q901", label: "scientist" } ] },
      { key: "medicine", label: "医学", occupations: [ { qid: "Q39631", label: "physician" } ] },
      { key: "technology", label: "技術", occupations: [ { qid: "Q81096", label: "engineer" }, { qid: "Q82594", label: "computer scientist" } ] },
      { key: "education", label: "教育", occupations: [ { qid: "Q37226", label: "teacher" } ] },
      { key: "journalism", label: "ジャーナリズム", occupations: [ { qid: "Q1930187", label: "journalist" } ] },
      { key: "literature", label: "文学", occupations: [ { qid: "Q36180", label: "writer" } ] },
      { key: "music", label: "音楽", occupations: [ { qid: "Q639669", label: "musician" } ] },
      { key: "film", label: "映画", occupations: [ { qid: "Q33999", label: "actor" } ] },
      { key: "sports", label: "スポーツ", occupations: [ { qid: "Q2066131", label: "athlete" } ] }
    ].freeze

    class << self
      delegate :fetch_people_for_preset, :presets, to: :new
    end

    def presets
      GENRE_PRESETS.map do |preset|
        {
          key: preset.fetch(:key),
          label: preset.fetch(:label),
          occupations: preset.fetch(:occupations).map(&:dup)
        }
      end
    end

    def fetch_people_for_preset(preset_key:, limit: 20, offset: 0)
      preset = preset_for(preset_key)
      normalized_limit = limit.to_i.clamp(1, MAX_BATCH_SIZE)
      normalized_offset = [ offset.to_i, 0 ].max
      per_occupation_limit = [ (normalized_limit.to_f / preset.fetch(:occupations).length).ceil, 1 ].max
      profiles = []
      seen_ids = {}

      preset.fetch(:occupations).each do |occupation|
        entity_ids = search_entity_ids(
          occupation_qid: occupation.fetch(:qid),
          limit: per_occupation_limit,
          offset: normalized_offset
        )
        next if entity_ids.empty?

        entities = fetch_entity_summaries(entity_ids)

        entity_ids.each do |entity_id|
          next if seen_ids[entity_id]

          profile = normalize_profile(
            entity_id,
            entities[entity_id],
            preset: preset,
            occupation_label: occupation.fetch(:label)
          )
          next if profile.blank?

          seen_ids[entity_id] = true
          profiles << profile
          break if profiles.length >= normalized_limit
        end

        break if profiles.length >= normalized_limit
      end

      profiles
    end

    private

    def preset_for(preset_key)
      preset = GENRE_PRESETS.find { |entry| entry.fetch(:key) == preset_key.to_s }
      return preset if preset.present?

      raise ExternalPeople::Error, "未対応のジャンルです。"
    end

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

    def normalize_profile(entity_id, entity, preset:, occupation_label:)
      return if entity.blank?

      display_name = extract_localized_text(entity["labels"]).presence || entity_id
      description = extract_localized_text(entity["descriptions"]).presence || "#{preset.fetch(:label)}の人物"

      {
        source_name: "wikidata",
        external_id: entity_id,
        source_url: wikidata_url(entity_id),
        fetched_at: Time.current,
        display_name: display_name,
        summary: description,
        bio: [ description, "ジャンル: #{preset.fetch(:label)}", "役割候補: #{occupation_label}" ].join("\n"),
        tags: [ preset.fetch(:label), occupation_label ],
        affiliations: []
      }
    end

    def wikidata_url(entity_id)
      "https://www.wikidata.org/wiki/#{entity_id}"
    end
  end
end
