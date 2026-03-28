class RelationshipGraphBuilder
  SIMILAR_TONE = "similar".freeze
  DIVERSE_TONE = "diverse".freeze

  def initialize(people:, encounter_cases:, focal_person: nil, profile_metadata_by_person_id: {})
    @people = Array(people).compact.uniq { |person| person.id }
    @encounter_cases = Array(encounter_cases).compact
    @focal_person = focal_person
    @profile_metadata_by_person_id = profile_metadata_by_person_id
  end

  def payload
    {
      centerId: @focal_person&.id,
      nodes: nodes,
      edges: edges
    }
  end

  private

  def nodes
    @people.map do |person|
      {
        id: person.id,
        label: person.display_name,
        href: Rails.application.routes.url_helpers.person_path(person),
        role: person.id == @focal_person&.id ? "focus" : "person"
      }
    end
  end

  def edges
    shared_pairs.map do |pair, pair_data|
      left = people_by_id.fetch(pair.first)
      right = people_by_id.fetch(pair.last)
      shared_tags = tag_names_for(left) & tag_names_for(right)
      shared_organizations = organization_names_for(left) & organization_names_for(right)
      classification = RelationshipKindClassifier.classify(
        shared_tags: shared_tags,
        shared_organizations: shared_organizations,
        shared_case_count: pair_data[:cases].length,
        shared_outcome_directions: pair_data[:cases].flat_map { |encounter_case| encounter_case.case_outcomes.map(&:outcome_direction) },
        shared_insight_types: pair_data[:cases].flat_map { |encounter_case| encounter_case.case_insights.map(&:insight_type) },
        role_pairs: role_pairs_for(pair_data[:cases], left, right),
        text_fragments: text_fragments_for(pair_data[:cases])
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
        sharedCaseCount: pair_data[:cases].length
      }
    end
  end

  def shared_pairs
    @encounter_cases.each_with_object(Hash.new { |hash, key| hash[key] = { cases: [] } }) do |encounter_case, pairs|
      participant_ids = encounter_case.people.map(&:id).compact & people_by_id.keys
      participant_ids.combination(2) do |left_id, right_id|
        pairs[[left_id, right_id].sort][:cases] << encounter_case
      end
    end
  end

  def role_pairs_for(encounter_cases, left, right)
    encounter_cases.filter_map do |encounter_case|
      left_role = encounter_case.case_participants.find { |participant| participant.person_id == left.id }&.participation_role
      right_role = encounter_case.case_participants.find { |participant| participant.person_id == right.id }&.participation_role
      next if left_role.blank? || right_role.blank?

      [ left_role, right_role ]
    end
  end

  def text_fragments_for(encounter_cases)
    encounter_cases.flat_map do |encounter_case|
      [
        encounter_case.title,
        encounter_case.summary,
        encounter_case.background,
        encounter_case.case_outcomes.map(&:description),
        encounter_case.case_insights.map(&:description),
        encounter_case.case_insights.map(&:application_note)
      ]
    end.flatten.compact
  end

  def tag_names_for(person)
    Array(metadata_for(person)[:tags]).presence || person.tags.map(&:name)
  end

  def organization_names_for(person)
    Array(metadata_for(person)[:organizations]).presence || person.organizations.map(&:name)
  end

  def metadata_for(person)
    @profile_metadata_by_person_id.fetch(person.id, {})
  end

  def people_by_id
    @people_by_id ||= @people.index_by(&:id)
  end
end
