class PersonNeighborhoodGraphBuilder
  MAX_NEW_NEIGHBORS_PER_STEP = {
    1 => 7,
    2 => 10,
    3 => 12
  }.freeze
  MAX_NON_FOCAL_EDGES = {
    1 => 10,
    2 => 18,
    3 => 28
  }.freeze

  def initialize(focal_person:, candidates:, focal_metadata: {}, depth: 1)
    @focal_person = focal_person
    @candidates = Array(candidates).compact.reject { |person| person.id == focal_person.id }.uniq { |person| person.id }
    @focal_metadata = normalize_metadata(focal_metadata)
    @depth = depth.to_i.clamp(1, 3)
  end

  def payload
    return empty_payload if selected_people.length == 1

    {
      centerId: @focal_person.id,
      nodes: nodes,
      edges: edges
    }
  end

  private

  def empty_payload
    {
      centerId: @focal_person.id,
      nodes: [
        {
          id: @focal_person.id,
          label: @focal_person.display_name,
          href: Rails.application.routes.url_helpers.person_path(@focal_person),
          role: "focus"
        }
      ],
      edges: []
    }
  end

  def nodes
    selected_people.map do |person|
      {
        id: person.id,
        label: person.display_name,
        href: Rails.application.routes.url_helpers.person_path(person),
        role: person.id == @focal_person.id ? "focus" : "person"
      }
    end
  end

  def edges
    focal_edges + non_focal_edges
  end

  def focal_edges
    selected_people.reject { |person| person.id == @focal_person.id }.filter_map do |neighbor|
      relationship_payload(@focal_person, neighbor)
    end
  end

  def non_focal_edges
    selected_people.reject { |person| person.id == @focal_person.id }
                   .combination(2)
                   .filter_map { |left, right| relationship_payload(left, right) }
                   .sort_by { |payload| [ -payload[:weight], payload[:sourceLabel], payload[:targetLabel] ] }
                   .first(max_non_focal_edges)
  end

  def selected_people
    @selected_people ||= begin
      selected = { @focal_person.id => @focal_person }
      frontier = [ @focal_person ]

      1.upto(@depth) do |step|
        break if frontier.empty?

        candidate_scores = {}

        frontier.each do |source|
          @candidates.each do |candidate|
            next if selected.key?(candidate.id)

            data = relationship_data(source, candidate)
            next if data[:score].zero?

            existing = candidate_scores[candidate.id]
            next if existing && existing[:score] >= data[:score]

            candidate_scores[candidate.id] = { person: candidate, score: data[:score] }
          end
        end

        next_frontier = candidate_scores.values.sort_by { |entry| [ -entry[:score], entry[:person].display_name ] }
                                        .first(max_new_neighbors_for_step(step))
                                        .map { |entry| entry[:person] }

        next if next_frontier.empty?

        next_frontier.each { |person| selected[person.id] = person }
        frontier = next_frontier
      end

      selected.values
    end
  end

  def relationship_payload(left, right)
    data = relationship_data(left, right)
    return if data[:score].zero?
    classification = RelationshipKindClassifier.classify(
      shared_tags: data[:shared_tags],
      shared_organizations: data[:shared_organizations]
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
      weight: data[:score]
    }
  end

  def max_new_neighbors_for_step(step)
    MAX_NEW_NEIGHBORS_PER_STEP.fetch(step, MAX_NEW_NEIGHBORS_PER_STEP.fetch(3))
  end

  def max_non_focal_edges
    MAX_NON_FOCAL_EDGES.fetch(@depth, MAX_NON_FOCAL_EDGES.fetch(3))
  end

  def relationship_data(left, right)
    left_metadata = metadata_for(left)
    right_metadata = metadata_for(right)
    shared_tags = left_metadata[:tags] & right_metadata[:tags]
    shared_organizations = left_metadata[:organizations] & right_metadata[:organizations]

    {
      shared_tags: shared_tags,
      shared_organizations: shared_organizations,
      score: (shared_organizations.length * 5) + (shared_tags.length * 3)
    }
  end

  def metadata_for(person)
    return @focal_metadata if person.id == @focal_person.id && (@focal_metadata[:tags].any? || @focal_metadata[:organizations].any?)

    {
      tags: normalized_terms(person.tags.map(&:name) + person.person_external_profiles.flat_map(&:cached_graph_tags)),
      organizations: normalized_terms(person.organizations.map(&:name) + person.person_external_profiles.flat_map(&:cached_graph_organizations))
    }
  end

  def normalize_metadata(metadata)
    {
      tags: normalized_terms(metadata[:tags]),
      organizations: normalized_terms(metadata[:organizations])
    }
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
end
