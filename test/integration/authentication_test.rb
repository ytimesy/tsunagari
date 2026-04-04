require 'test_helper'

class AuthenticationTest < ActionDispatch::IntegrationTest
  test 'guest is redirected to login for editing routes' do
    person = Person.create!(display_name: 'Draft Person', publication_status: 'draft')

    get new_person_path
    assert_redirected_to login_path

    get edit_person_path(person)
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

  test 'editor can view draft and review people' do
    sign_in_as(create_user)

    draft_person = Person.create!(display_name: 'Draft Person', publication_status: 'draft')
    review_person = Person.create!(display_name: 'Review Person', publication_status: 'review')

    get people_path
    assert_response :success
    assert_match 'Draft Person', response.body
    assert_match 'Review Person', response.body

    get person_path(draft_person)
    assert_response :success

    get person_path(review_person)
    assert_response :success
  end

  test 'editor sees publication status summary on home' do
    sign_in_as(create_user)

    Person.create!(display_name: 'Draft Person', publication_status: 'draft')
    Person.create!(display_name: 'Review Person', publication_status: 'review')
    Person.create!(display_name: 'Published Person', publication_status: 'published', recommended_for: '編集方針の相談')

    get root_path

    assert_response :success
    assert_match '公開状態サマリー', response.body
    assert_match '活用視点あり', response.body
    assert_match '/people?publication_status=draft', response.body
    assert_match '/people?publication_status=review', response.body
    assert_match 'アーカイブ以外を公開', response.body
  end
end
