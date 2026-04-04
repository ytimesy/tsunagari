
require 'test_helper'

class SavedPeopleTest < ActionDispatch::IntegrationTest
  test 'guest can save people, annotate them, export csv, and remove them' do
    person = Person.create!(display_name: 'Saved Person', publication_status: 'published', summary: '保存リストで使う人物です。')
    tag = Tag.create!(name: 'AI')
    PersonTag.create!(person: person, tag: tag)

    post save_person_path(person)
    assert_redirected_to saved_people_path
    follow_redirect!
    assert_response :success
    assert_match '保存リスト', response.body
    assert_match 'Saved Person', response.body

    patch update_saved_person_note_path(person), params: { saved_person: { note: '登壇候補として保持' } }
    assert_redirected_to saved_people_path
    follow_redirect!
    assert_match '登壇候補として保持', response.body

    get export_saved_people_path(format: :csv)
    assert_response :success
    assert_includes response.media_type, 'text/csv'
    assert_includes response.body, 'Saved Person'
    assert_includes response.body, '登壇候補として保持'

    delete remove_saved_person_path(person)
    assert_redirected_to saved_people_path
    follow_redirect!
    assert_match 'まだ保存した人物はありません', response.body
  end

  test 'editor can save a draft person' do
    sign_in_as(create_user)
    person = Person.create!(display_name: 'Draft Person', publication_status: 'draft')

    post save_person_path(person)

    assert_redirected_to saved_people_path
    follow_redirect!
    assert_match 'Draft Person', response.body
  end
end
