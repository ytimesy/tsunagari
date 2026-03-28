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
    shared_pairs.map do |pair, shared_case_count|
      left = people_by_id.fetch(pair.first)
      right = people_by_id.fetch(pair.last)
      tone, reason = classify_relationship(left, right, shared_case_count)

      {
        source: left.id,
        target: right.id,
        sourceLabel: left.display_name,
        targetLabel: right.display_name,
        tone: tone,
        reason: reason,
        sharedCaseCount: shared_case_count
      }
    end
  end

  def shared_pairs
    @encounter_cases.each_with_object(Hash.new(0)) do |encounter_case, pairs|
      participant_ids = encounter_case.people.map(&:id).compact & people_by_id.keys
      participant_ids.combination(2) do |left_id, right_id|
        pairs[[left_id, right_id].sort] += 1
      end
    end
  end

  def classify_relationship(left, right, shared_case_count)
    shared_tags = tag_names_for(left) & tag_names_for(right)
    shared_organizations = organization_names_for(left) & organization_names_for(right)

    reasons = []
    reasons << "共通タグ: #{shared_tags.first(2).join(', ')}" if shared_tags.any?
    reasons << "同じ所属: #{shared_organizations.first(2).join(', ')}" if shared_organizations.any?
    reasons << "#{shared_case_count}件の事例で接点" if shared_case_count > 1

    if shared_tags.any? || shared_organizations.any?
      [SIMILAR_TONE, reasons.join(" / ")]
    else
      [DIVERSE_TONE, "所属やタグが異なる組み合わせ"]
    end
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
