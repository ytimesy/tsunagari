module ExternalPeople
  class WikidataClient < BaseClient
    API_ENDPOINT = "https://www.wikidata.org/w/api.php".freeze
    ENTITY_DATA_ENDPOINT = "https://www.wikidata.org/wiki/Special:EntityData".freeze
    HUMAN_QID = "Q5".freeze
    OCCUPATION_PROPERTY = "P106".freeze
    FIELD_OF_WORK_PROPERTY = "P101".freeze
    EMPLOYER_PROPERTY = "P108".freeze
    MEMBER_OF_PROPERTY = "P463".freeze
    POSITION_HELD_PROPERTY = "P39".freeze
    EDUCATED_AT_PROPERTY = "P69".freeze
    INSTANCE_OF_PROPERTY = "P31".freeze

    class << self
      delegate :search, :fetch_profile, to: :new
    end

    def search(query)
      json = fetch_json(API_ENDPOINT, params: {
        action: "wbsearchentities",
        search: query,
        language: "ja",
        uselang: "ja",
        type: "item",
        limit: 8,
        format: "json"
      })

      Array(json["search"]).map do |result|
        {
          source_name: "wikidata",
          external_id: result["id"],
          display_name: result["label"],
          subtitle: result["description"].presence || "Wikidata",
          badges: [ "Wikidata", result["match"]&.dig("language") ].compact,
          source_url: wikidata_url(result["id"])
        }
      end
    end

    def fetch_profile(external_id)
      json = fetch_json("#{ENTITY_DATA_ENDPOINT}/#{external_id}.json")
      entity = json.fetch("entities", {}).fetch(external_id)

      if entity["claims"].present? && human_entity?(entity) == false
        raise ExternalPeople::Error, "Wikidata 上で人物データとして判定できませんでした。"
      end

      linked_ids = extract_linked_entity_ids(entity)
      labels_by_id = fetch_entity_labels(linked_ids)

      occupations = labels_for(entity, OCCUPATION_PROPERTY, labels_by_id)
      fields = labels_for(entity, FIELD_OF_WORK_PROPERTY, labels_by_id)
      organizations = labels_for(entity, EMPLOYER_PROPERTY, labels_by_id)
      organizations += labels_for(entity, MEMBER_OF_PROPERTY, labels_by_id)
      organizations += labels_for(entity, EDUCATED_AT_PROPERTY, labels_by_id)
      organizations.uniq!

      display_name = extract_localized_text(entity["labels"])
      description = extract_localized_text(entity["descriptions"])
      aliases = extract_aliases(entity["aliases"])

      bio_parts = []
      bio_parts << description if description.present?
      bio_parts << "別名: #{aliases.join(' / ')}" if aliases.any?
      bio_parts << "職業: #{occupations.join(', ')}" if occupations.any?
      bio_parts << "分野: #{fields.join(', ')}" if fields.any?

      {
        source_name: "wikidata",
        external_id: external_id,
        source_url: wikidata_url(external_id),
        fetched_at: Time.current,
        display_name: display_name,
        summary: description,
        bio: bio_parts.join("\n"),
        tags: (occupations + fields).first(6),
        affiliations: organizations.first(3).map { |name| { name: name, category: "organization" } }
      }
    end

    private

    def human_entity?(entity)
      human_flags = Array(entity.dig("claims", INSTANCE_OF_PROPERTY)).filter_map do |claim|
        claim.dig("mainsnak", "datavalue", "value", "id")
      end

      return nil if human_flags.empty?

      human_flags.include?(HUMAN_QID)
    end

    def extract_linked_entity_ids(entity)
      [ OCCUPATION_PROPERTY, FIELD_OF_WORK_PROPERTY, EMPLOYER_PROPERTY, MEMBER_OF_PROPERTY, POSITION_HELD_PROPERTY, EDUCATED_AT_PROPERTY ].flat_map do |property|
        Array(entity.dig("claims", property)).filter_map do |claim|
          claim.dig("mainsnak", "datavalue", "value", "id")
        end
      end.uniq
    end

    def fetch_entity_labels(ids)
      return {} if ids.empty?

      json = fetch_json(API_ENDPOINT, params: {
        action: "wbgetentities",
        ids: ids.join("|"),
        props: "labels",
        languages: "ja|en",
        format: "json"
      })

      json.fetch("entities", {}).transform_values do |entity|
        extract_localized_text(entity["labels"])
      end
    end

    def labels_for(entity, property, labels_by_id)
      Array(entity.dig("claims", property)).filter_map do |claim|
        labels_by_id[claim.dig("mainsnak", "datavalue", "value", "id")].presence
      end.uniq
    end

    def wikidata_url(external_id)
      "https://www.wikidata.org/wiki/#{external_id}"
    end
  end
end
