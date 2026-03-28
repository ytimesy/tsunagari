require "test_helper"

class UserFlowsTest < ActionDispatch::IntegrationTest
  test "visitor can create and update a person and encounter case" do
    get new_person_path
    assert_response :success

    post people_path, params: {
      person: {
        display_name: "Ada Lovelace",
        summary: "Poetical science pioneer",
        bio: "Known for linking imagination and computation.",
        publication_status: "published",
        tag_list: "Math, Computing",
        primary_organization_name: "Analytical Society",
        primary_organization_category: "community",
        primary_affiliation_title: "Member"
      }
    }

    person = Person.find_by!(display_name: "Ada Lovelace")
    assert_redirected_to person_path(person)
    assert_equal [ "Computing", "Math" ], person.tags.order(:name).pluck(:name)

    patch person_path(person), params: {
      person: {
        display_name: "Ada Lovelace",
        summary: "Poetical science pioneer and editor",
        bio: "Known for linking imagination and computation.",
        publication_status: "review",
        tag_list: "Math, Computing, Writing",
        primary_organization_name: "Analytical Society",
        primary_organization_category: "community",
        primary_affiliation_title: "Member"
      }
    }

    assert_redirected_to person_path(person)
    assert_equal "review", person.reload.publication_status
    assert_equal [ "Computing", "Math", "Writing" ], person.tags.order(:name).pluck(:name)

    get new_encounter_case_path
    assert_response :success

    post encounter_cases_path, params: {
      encounter_case: {
        title: "Ada and Charles started a new line of inquiry",
        summary: "A meeting that pushed analytical work forward.",
        background: "They met around shared interest in machines.",
        happened_on: Date.new(1843, 1, 1),
        place: "London",
        publication_status: "published",
        tag_list: "Collaboration, Innovation",
        participant_names: "Ada Lovelace, Charles Babbage",
        participant_role: "participant",
        outcome_category: "innovation",
        outcome_direction: "positive",
        outcome_description: "A new computational perspective emerged.",
        impact_scope: "field",
        evidence_level: "documented",
        insight_type: "enabler",
        insight_description: "They had a shared curiosity and technical depth.",
        application_note: "Shared inquiry spaces matter.",
        source_title: "Biography",
        source_url: "https://example.com/ada-charles",
        source_type: "article",
        source_published_on: Date.new(2024, 1, 1)
      }
    }

    encounter_case = EncounterCase.find_by!(title: "Ada and Charles started a new line of inquiry")
    assert_redirected_to encounter_case_path(encounter_case)
    assert_equal 2, encounter_case.people.count
    assert_equal "positive", encounter_case.case_outcomes.first.outcome_direction

    get encounter_case_path(encounter_case)
    assert_response :success
    assert_match "人物関係図", response.body
    assert_match "似たもの同士", response.body
    assert_match "Ada Lovelace × Charles Babbage", response.body

    patch encounter_case_path(encounter_case), params: {
      encounter_case: {
        title: "Ada and Charles started a new line of inquiry",
        summary: "The meeting led to a more explicit computational framing.",
        background: "They met around shared interest in machines.",
        happened_on: Date.new(1843, 1, 1),
        place: "London / correspondence",
        publication_status: "review",
        tag_list: "Collaboration, Innovation",
        participant_names: "Ada Lovelace, Charles Babbage",
        participant_role: "participant",
        outcome_category: "innovation",
        outcome_direction: "mixed",
        outcome_description: "A new computational perspective emerged, but adoption remained limited.",
        impact_scope: "field",
        evidence_level: "documented",
        insight_type: "lesson",
        insight_description: "Strong ideas still need translation into institutions.",
        application_note: "Pair original thinkers with implementers earlier.",
        source_title: "Biography",
        source_url: "https://example.com/ada-charles",
        source_type: "article",
        source_published_on: Date.new(2024, 1, 1)
      }
    }

    assert_redirected_to encounter_case_path(encounter_case)
    assert_equal "review", encounter_case.reload.publication_status
    assert_equal "mixed", encounter_case.case_outcomes.first.outcome_direction
  end

  test "wiki shows draft and published people and cases to every visitor" do
    public_person = Person.create!(display_name: "Public Person", publication_status: "published")
    draft_person = Person.create!(display_name: "Draft Person", publication_status: "draft")
    public_case = EncounterCase.create!(title: "Public Case", publication_status: "published")
    draft_case = EncounterCase.create!(title: "Draft Case", publication_status: "draft")

    get people_path
    assert_response :success
    assert_match "Public Person", response.body
    assert_match "Draft Person", response.body

    get encounter_cases_path
    assert_response :success
    assert_match "Public Case", response.body
    assert_match "Draft Case", response.body

    get person_path(public_person)
    assert_response :success

    get person_path(draft_person)
    assert_response :success

    get encounter_case_path(public_case)
    assert_response :success

    get encounter_case_path(draft_case)
    assert_response :success
  end

  test "visitor can add research notes to person and encounter case" do
    person = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    encounter_case = EncounterCase.create!(title: "Grace met a Navy team", publication_status: "published")

    post research_notes_path, params: {
      research_note: {
        person_id: person.id,
        note_kind: "research",
        body: "Follow up with an oral history source."
      }
    }

    assert_redirected_to person_path(person)
    assert_equal 1, person.research_notes.count

    post research_notes_path, params: {
      research_note: {
        encounter_case_id: encounter_case.id,
        note_kind: "hypothesis",
        body: "Trust and institutional backing seem central."
      }
    }

    assert_redirected_to encounter_case_path(encounter_case)
    assert_equal 1, encounter_case.research_notes.count
  end

  test "case detail shows setbacks and lessons without login" do
    encounter_case = EncounterCase.create!(
      title: "A civic project stalled after an initial meeting",
      summary: "The meeting created energy, but the collaboration later stalled.",
      publication_status: "published"
    )
    encounter_case.case_outcomes.create!(
      category: "coordination",
      outcome_direction: "negative",
      description: "The project stalled because ownership stayed ambiguous.",
      evidence_level: "reported"
    )
    encounter_case.case_insights.create!(
      insight_type: "barrier",
      description: "Ambiguous roles and delayed decisions weakened trust.",
      application_note: "Set decision owners before the first collaborative sprint."
    )

    get encounter_case_path(encounter_case)
    assert_response :success
    assert_match "失敗・後退", response.body
    assert_match "阻害要因", response.body
    assert_match "ownership stayed ambiguous", response.body
    assert_match "メモを残す", response.body
  end

  test "person detail shows relationship map around the focal person" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")
    computing = Tag.create!(name: "Computing")
    ada.tags << computing
    babbage.tags << computing

    encounter_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    encounter_case.case_participants.create!(person: ada, participation_role: "participant")
    encounter_case.case_participants.create!(person: babbage, participation_role: "participant")
    encounter_case.case_participants.create!(person: helper, participation_role: "participant")

    get person_path(ada)
    assert_response :success
    assert_match "人物関係図", response.body
    assert_match "Ada Lovelace × Charles Babbage", response.body
    assert_match "Ada Lovelace × Community Organizer", response.body
  end
end
