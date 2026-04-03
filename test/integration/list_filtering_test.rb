require 'test_helper'

class ListFilteringTest < ActionDispatch::IntegrationTest
  test 'guest people filters stay on published records only' do
    public_person = Person.create!(display_name: 'Public Analyst', publication_status: 'published')
    draft_person = Person.create!(display_name: 'Draft Analyst', publication_status: 'draft')
    computing = Tag.create!(name: 'Computing')
    public_person.tags << computing
    draft_person.tags << computing

    get people_path, params: { tag: 'Computing', publication_status: 'draft' }

    assert_response :success
    assert_match 'Public Analyst', response.body
    assert_no_match 'Draft Analyst', response.body
    assert_match '条件をリセット', response.body
  end

  test 'editor can filter people by status, source presence, and sort' do
    sign_in_as(create_user)

    external_draft = Person.create!(display_name: 'External Draft', publication_status: 'draft')
    external_draft.person_external_profiles.create!(
      source_name: 'wikidata',
      external_id: 'Q1',
      source_url: 'https://www.wikidata.org/wiki/Q1',
      fetched_at: Time.current
    )
    local_review = Person.create!(display_name: 'Local Review', publication_status: 'review')
    external_draft.update_columns(updated_at: 3.days.ago)
    local_review.update_columns(updated_at: Time.current)

    get people_path, params: { publication_status: 'draft', source_filter: 'external' }

    assert_response :success
    assert_match 'External Draft', response.body
    assert_no_match 'Local Review', response.body

    get people_path, params: { sort: 'recently_updated' }

    assert_response :success
    assert_operator response.body.index('Local Review'), :<, response.body.index('External Draft')
  end

  test 'editor can filter encounter cases by status, evidence, dates, and sort' do
    sign_in_as(create_user)

    matching_case = EncounterCase.create!(
      title: 'Draft Coordination Case',
      publication_status: 'draft',
      happened_on: Date.new(2024, 5, 1)
    )
    matching_case.case_outcomes.create!(
      category: 'coordination',
      outcome_direction: 'negative',
      description: 'Ownership stayed unclear.',
      evidence_level: 'hypothesis'
    )
    matching_case.tags << Tag.create!(name: 'Coordination')

    older_case = EncounterCase.create!(
      title: 'Older Coordination Case',
      publication_status: 'draft',
      happened_on: Date.new(2022, 1, 1)
    )
    older_case.case_outcomes.create!(
      category: 'coordination',
      outcome_direction: 'negative',
      description: 'The team stalled.',
      evidence_level: 'hypothesis'
    )
    older_case.tags << Tag.find_by!(normalized_name: 'coordination')

    review_case = EncounterCase.create!(
      title: 'Review Learning Case',
      publication_status: 'review',
      happened_on: Date.new(2024, 7, 1)
    )
    review_case.case_outcomes.create!(
      category: 'learning',
      outcome_direction: 'mixed',
      description: 'Mixed signals emerged.',
      evidence_level: 'observed'
    )

    get encounter_cases_path, params: {
      tag: 'Coordination',
      outcome_direction: 'negative',
      evidence_level: 'hypothesis',
      publication_status: 'draft',
      date_from: '2023-01-01'
    }

    assert_response :success
    assert_match 'Draft Coordination Case', response.body
    assert_no_match 'Older Coordination Case', response.body
    assert_no_match 'Review Learning Case', response.body

    get encounter_cases_path, params: { publication_status: 'draft', sort: 'oldest' }

    assert_response :success
    assert_operator response.body.index('Older Coordination Case'), :<, response.body.index('Draft Coordination Case')
  end
end
