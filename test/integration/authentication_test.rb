require 'test_helper'

class AuthenticationTest < ActionDispatch::IntegrationTest
  test 'guest is redirected to login for editing routes' do
    person = Person.create!(display_name: 'Draft Person', publication_status: 'draft')
    encounter_case = EncounterCase.create!(title: 'Draft Case', publication_status: 'draft')

    get new_person_path
    assert_redirected_to login_path

    get edit_person_path(person)
    assert_redirected_to login_path

    get new_encounter_case_path
    assert_redirected_to login_path

    get edit_encounter_case_path(encounter_case)
    assert_redirected_to login_path

    get new_person_import_path
    assert_redirected_to login_path

    post research_notes_path, params: {
      research_note: {
        person_id: person.id,
        note_kind: 'research',
        body: 'Hidden note'
      }
    }
    assert_redirected_to login_path
  end

  test 'editor can view draft and review records' do
    sign_in_as(create_user)

    draft_person = Person.create!(display_name: 'Draft Person', publication_status: 'draft')
    review_person = Person.create!(display_name: 'Review Person', publication_status: 'review')
    draft_case = EncounterCase.create!(title: 'Draft Case', publication_status: 'draft')
    review_case = EncounterCase.create!(title: 'Review Case', publication_status: 'review')

    get people_path
    assert_response :success
    assert_match 'Draft Person', response.body
    assert_match 'Review Person', response.body

    get person_path(draft_person)
    assert_response :success

    get person_path(review_person)
    assert_response :success

    get encounter_cases_path
    assert_response :success
    assert_match 'Draft Case', response.body
    assert_match 'Review Case', response.body

    get encounter_case_path(draft_case)
    assert_response :success

    get encounter_case_path(review_case)
    assert_response :success
  end


  test 'editor sees publication status summary on home' do
    sign_in_as(create_user)

    Person.create!(display_name: 'Draft Person', publication_status: 'draft')
    Person.create!(display_name: 'Review Person', publication_status: 'review')
    Person.create!(display_name: 'Published Person', publication_status: 'published')
    EncounterCase.create!(title: 'Draft Case', publication_status: 'draft')
    EncounterCase.create!(title: 'Published Case', publication_status: 'published')

    get root_path

    assert_response :success
    assert_match '公開状態サマリー', response.body
    assert_match '事例の公開状態', response.body
    assert_match '/people?publication_status=draft', response.body
    assert_match '/people?publication_status=review', response.body
    assert_match '/cases?publication_status=draft', response.body
    assert_match 'アーカイブ以外を公開', response.body
  end
end
