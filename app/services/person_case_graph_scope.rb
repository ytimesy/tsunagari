class PersonCaseGraphScope
  MAX_NEW_PEOPLE_PER_STEP = {
    1 => 7,
    2 => 10,
    3 => 14
  }.freeze

  def initialize(focal_person:, depth:)
    @focal_person = focal_person
    @depth = depth.to_i.clamp(1, 3)
  end

  def build
    selected_people = { @focal_person.id => @focal_person }
    selected_cases = {}
    frontier = [ @focal_person ]

    1.upto(@depth) do |step|
      break if frontier.empty?

      layer_cases = cases_for(frontier)
      layer_cases.each { |encounter_case| selected_cases[encounter_case.id] = encounter_case }

      candidate_counts = Hash.new(0)
      candidate_people = {}

      layer_cases.each do |encounter_case|
        encounter_case.people.select(&:publicly_visible?).each do |person|
          next if selected_people.key?(person.id)

          candidate_people[person.id] ||= person
          candidate_counts[person.id] += 1
        end
      end

      next_frontier_ids = candidate_counts.sort_by do |person_id, count|
        [ -count, candidate_people.fetch(person_id).display_name ]
      end.first(limit_for_step(step)).map(&:first)

      frontier = next_frontier_ids.map { |person_id| candidate_people.fetch(person_id) }
      frontier.each { |person| selected_people[person.id] = person }
    end

    people_ids = selected_people.keys
    filtered_cases = selected_cases.values.select do |encounter_case|
      (encounter_case.people.select(&:publicly_visible?).map(&:id) & people_ids).length >= 2
    end

    {
      people: selected_people.values,
      encounter_cases: filtered_cases
    }
  end

  private

  def limit_for_step(step)
    MAX_NEW_PEOPLE_PER_STEP.fetch(step, MAX_NEW_PEOPLE_PER_STEP.fetch(3))
  end

  def cases_for(frontier)
    frontier_ids = frontier.map(&:id)
    return [] if frontier_ids.empty?

    EncounterCase.publicly_visible.includes(
      :case_outcomes,
      :case_insights,
      case_participants: :person,
      people: [ :person_external_profiles, :tags, { person_affiliations: :organization } ]
    ).joins(:case_participants)
     .where(case_participants: { person_id: frontier_ids })
     .distinct
     .order(happened_on: :desc, published_at: :desc)
     .to_a
  end
end
