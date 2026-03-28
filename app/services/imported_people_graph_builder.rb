class ImportedPeopleGraphBuilder
  MAX_TAG_GROUP_SIZE = 18
  MAX_ORGANIZATION_GROUP_SIZE = 24
  MAX_EDGES_PER_PERSON = 4
  MAX_TOTAL_EDGES = 220

  def initialize(people:, profile_metadata_by_person_id: {})
    @people = Array(people).compact.uniq { |person| person.id }
    @profile_metadata_by_person_id = profile_metadata_by_person_id || {}
  end

  def payload
    {
      centerId: nil,
      nodes: nodes,
      edges: selected_edges,
      layout: "rings"
    }
  end

  def summary
    {
      people_count: @people.count,
      connected_people_count: connected_person_ids.count,
      isolated_people_count: @people.count - connected_person_ids.count,
      edge_count: selected_edges.count,
      missing_cache_count: missing_cache_count,
      top_organizations: top_terms_for(:organizations),
      top_tags: top_terms_for(:tags),
      source_breakdown: source_breakdown
    }
  end

  private

  def nodes
    sorted_people.map do |person|
      {
        id: person.id,
        label: person.display_name,
        href: Rails.application.routes.url_helpers.person_path(person),
        role: connected_person_ids.include?(person.id) ? "person" : "isolated",
        degree: degree_by_person_id.fetch(person.id, 0)
      }
    end
  end

  def sorted_people
    @sorted_people ||= @people.sort_by do |person|
      [ -degree_by_person_id.fetch(person.id, 0), person.display_name ]
    end
  end

  def selected_edges
    @selected_edges ||= begin
      selected = []
      edge_counts = Hash.new(0)

      ranked_edge_candidates.each do |candidate|
        next if edge_counts[candidate[:source]] >= MAX_EDGES_PER_PERSON
        next if edge_counts[candidate[:target]] >= MAX_EDGES_PER_PERSON

        selected << candidate
        edge_counts[candidate[:source]] += 1
        edge_counts[candidate[:target]] += 1
        break if selected.length >= MAX_TOTAL_EDGES
      end

      selected
    end
  end

  def ranked_edge_candidates
    relationship_pairs.map do |pair, values|
      left = people_by_id.fetch(pair.first)
      right = people_by_id.fetch(pair.last)
      shared_tags = values[:shared_tags]
      shared_organizations = values[:shared_organizations]
      classification = RelationshipKindClassifier.classify(
        shared_tags: shared_tags,
        shared_organizations: shared_organizations
      )

      {
        source: left.id,
        target: right.id,
        sourceLabel: left.display_name,
        targetLabel: right.display_name,
        tone: classification[:tone],
        kind: classification[:kind],
        kindLabel: classification[:kind_label],
        kindDescription: classification[:kind_description],
        reason: classification[:reason],
        weight: weight_for(shared_tags:, shared_organizations:)
      }
    end.sort_by do |candidate|
      [
        -candidate[:weight],
        candidate[:tone] == RelationshipGraphBuilder::SIMILAR_TONE ? 0 : 1,
        candidate[:sourceLabel],
        candidate[:targetLabel]
      ]
    end
  end

  def relationship_pairs
    @relationship_pairs ||= begin
      accumulator = Hash.new do |hash, key|
        hash[key] = { shared_tags: [], shared_organizations: [] }
      end

      add_term_pairs!(accumulator, :shared_tags, metadata_key: :tags, max_group_size: MAX_TAG_GROUP_SIZE)
      add_term_pairs!(accumulator, :shared_organizations, metadata_key: :organizations, max_group_size: MAX_ORGANIZATION_GROUP_SIZE)

      accumulator
    end
  end

  def add_term_pairs!(accumulator, bucket_key, metadata_key:, max_group_size:)
    grouped_terms(metadata_key).each do |term, person_ids|
      next if person_ids.size < 2
      next if person_ids.size > max_group_size

      person_ids.combination(2) do |left_id, right_id|
        accumulator[[ left_id, right_id ].sort][bucket_key] << term
      end
    end
  end

  def grouped_terms(metadata_key)
    metadata_index.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(person_id, metadata), groups|
      metadata.fetch(metadata_key).each do |term|
        groups[term] << person_id
      end
    end.transform_values(&:uniq)
  end

  def weight_for(shared_tags:, shared_organizations:)
    (shared_organizations.length * 5) + (shared_tags.length * 3)
  end

  def degree_by_person_id
    @degree_by_person_id ||= selected_edges.each_with_object(Hash.new(0)) do |edge, counts|
      counts[edge[:source]] += 1
      counts[edge[:target]] += 1
    end
  end

  def connected_person_ids
    @connected_person_ids ||= degree_by_person_id.keys
  end

  def metadata_index
    @metadata_index ||= @people.each_with_object({}) do |person, index|
      resolved_metadata = @profile_metadata_by_person_id.fetch(person.id, {})

      index[person.id] = {
        tags: normalized_terms(
          person.tags.map(&:name) +
          person.person_external_profiles.flat_map(&:cached_graph_tags) +
          Array(resolved_metadata[:tags])
        ),
        organizations: normalized_terms(
          person.organizations.map(&:name) +
          person.person_external_profiles.flat_map(&:cached_graph_organizations) +
          Array(resolved_metadata[:organizations])
        ),
        source_names: person.person_external_profiles.map(&:source_name).compact.uniq
      }
    end
  end

  def top_terms_for(key)
    metadata_index.values.each_with_object(Hash.new(0)) do |metadata, counts|
      metadata.fetch(key).each { |term| counts[term] += 1 }
    end.sort_by { |term, count| [ -count, term ] }.first(8)
  end

  def source_breakdown
    metadata_index.values.flat_map { |metadata| metadata[:source_names] }
                 .each_with_object(Hash.new(0)) { |source_name, counts| counts[source_name] += 1 }
                 .sort_by { |source_name, count| [ -count, source_name ] }
  end

  def missing_cache_count
    @people.count do |person|
      person.tags.empty? &&
        person.organizations.empty? &&
        person.person_external_profiles.all? do |profile|
          profile.cached_graph_tags.empty? && profile.cached_graph_organizations.empty?
        end
    end
  end

  def normalized_terms(values)
    seen = {}

    Array(values).filter_map do |value|
      term = value.to_s.squish
      next if term.blank?

      key = term.downcase
      next if seen[key]

      seen[key] = true
      term
    end
  end

  def people_by_id
    @people_by_id ||= @people.index_by(&:id)
  end
end
