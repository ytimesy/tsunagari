require "test_helper"

class UserFlowsTest < ActionDispatch::IntegrationTest
  test "editor can sign up and create a person and encounter case" do
    get sign_up_path
    assert_response :success

    post sign_up_path, params: {
      user: {
        email: "editor@example.com",
        password: "password",
        password_confirmation: "password"
      }
    }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_equal "editor@example.com", User.last.email

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
    assert_equal "published", person.publication_status
    assert_equal [ "Computing", "Math" ], person.tags.order(:name).pluck(:name)
    assert_equal "Analytical Society", person.primary_affiliation.organization.name

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
    assert_equal 1, encounter_case.case_outcomes.count
    assert_equal "positive", encounter_case.case_outcomes.first.outcome_direction
    assert_equal 1, encounter_case.case_insights.count
    assert_equal 1, encounter_case.sources.count
  end

  test "published case can show setbacks and lessons" do
    editor = create_editor(email: "editor4@example.com")
    sign_in_as(editor)

    post encounter_cases_path, params: {
      encounter_case: {
        title: "A civic project stalled after an initial meeting",
        summary: "The meeting created energy, but the collaboration later stalled.",
        background: "Expectations and decision rights were not aligned.",
        happened_on: Date.new(2025, 2, 1),
        place: "Osaka",
        publication_status: "published",
        tag_list: "Civic, Collaboration",
        participant_names: "Planner A, Researcher B",
        participant_role: "participant",
        outcome_category: "coordination",
        outcome_direction: "negative",
        outcome_description: "The project stalled because ownership stayed ambiguous.",
        impact_scope: "team",
        evidence_level: "reported",
        insight_type: "barrier",
        insight_description: "Ambiguous roles and delayed decisions weakened trust.",
        application_note: "Set decision owners before the first collaborative sprint.",
        source_title: "Postmortem interview",
        source_url: "https://example.com/stalled-project",
        source_type: "interview",
        source_published_on: Date.new(2025, 3, 1)
      }
    }

    encounter_case = EncounterCase.find_by!(title: "A civic project stalled after an initial meeting")
    assert_equal "negative", encounter_case.case_outcomes.first.outcome_direction
    assert_equal "barrier", encounter_case.case_insights.first.insight_type

    delete sign_out_path

    get encounter_case_path(encounter_case)
    assert_response :success
    assert_match "失敗・後退", response.body
    assert_match "阻害要因", response.body
    assert_match "ownership stayed ambiguous", response.body
  end

  test "guest sees only published people and encounter cases" do
    editor = create_editor(email: "editor2@example.com")
    public_person = Person.create!(display_name: "Public Person", publication_status: "published")
    draft_person = Person.create!(display_name: "Draft Person", publication_status: "draft")
    public_case = EncounterCase.create!(editor_user: editor, title: "Public Case", publication_status: "published")
    draft_case = EncounterCase.create!(editor_user: editor, title: "Draft Case", publication_status: "draft")

    get people_path
    assert_response :success
    assert_match "Public Person", response.body
    refute_match "Draft Person", response.body

    get encounter_cases_path
    assert_response :success
    assert_match "Public Case", response.body
    refute_match "Draft Case", response.body

    get person_path(public_person)
    assert_response :success

    get person_path(draft_person)
    assert_redirected_to people_path

    get encounter_case_path(public_case)
    assert_response :success

    get encounter_case_path(draft_case)
    assert_redirected_to encounter_cases_path
  end

  test "signed in editor can add research notes to person and encounter case" do
    editor = create_editor(email: "editor5@example.com")
    person = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    encounter_case = EncounterCase.create!(editor_user: editor, title: "Grace met a Navy team", publication_status: "published")

    sign_in_as(editor)

    post research_notes_path, params: {
      research_note: {
        person_id: person.id,
        note_kind: "research",
        body: "Follow up with an oral history source."
      }
    }

    assert_redirected_to person_path(person)
    assert_equal 1, editor.research_notes.where(person: person).count

    post research_notes_path, params: {
      research_note: {
        encounter_case_id: encounter_case.id,
        note_kind: "hypothesis",
        body: "Trust and institutional backing seem central."
      }
    }

    assert_redirected_to encounter_case_path(encounter_case)
    assert_equal 1, editor.research_notes.where(encounter_case: encounter_case).count
  end

  private

  def create_editor(email:)
    User.create!(
      email: email,
      password: "password",
      password_confirmation: "password",
      role: "editor",
      status: "active"
    )
  end

  def sign_in_as(user)
    post sign_in_path, params: {
      session: {
        email: user.email,
        password: "password"
      }
    }
  end
end
