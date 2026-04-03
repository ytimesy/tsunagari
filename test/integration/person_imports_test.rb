require 'test_helper'

class PersonImportsTest < ActionDispatch::IntegrationTest
  test 'editor can open the supplement flow with person context' do
    sign_in_as(create_user)

    person = Person.create!(display_name: 'Ada Lovelace', publication_status: 'published')
    results = [
      {
        source_name: 'wikidata',
        external_id: 'Q7259',
        display_name: 'Ada Lovelace',
        subtitle: 'English mathematician',
        badges: [ 'Wikidata' ],
        source_url: 'https://www.wikidata.org/wiki/Q7259'
      }
    ]

    get person_path(person)
    assert_response :success
    assert_match 'Wikidata / OpenAlexで補う', response.body

    with_stubbed_method(ExternalPeople::WikidataClient, :search, results) do
      get new_person_import_path, params: { q: person.display_name, person_id: person.id, source_name: 'wikidata' }
    end

    assert_response :success
    assert_match 'Wikidata / OpenAlexで補う', response.body
    assert_match '「Ada Lovelace」を土台に', response.body
    assert_match 'この人物へ取り込む', response.body
  end

  test 'editor can search external people candidates' do
    sign_in_as(create_user)

    results = [
      {
        source_name: 'wikidata',
        external_id: 'Q7259',
        display_name: 'Ada Lovelace',
        subtitle: 'English mathematician',
        badges: [ 'Wikidata' ],
        source_url: 'https://www.wikidata.org/wiki/Q7259'
      }
    ]

    with_stubbed_method(ExternalPeople::WikidataClient, :search, results) do
      get new_person_import_path, params: { source_name: 'wikidata', q: 'Ada Lovelace' }
    end

    assert_response :success
    assert_match 'Ada Lovelace', response.body
    assert_match 'Wikidata', response.body
    assert_match '人物録へ取り込む', response.body
  end

  test 'editor can import a new person from an external source' do
    sign_in_as(create_user)

    profile = {
      source_name: 'wikidata',
      external_id: 'Q7259',
      source_url: 'https://www.wikidata.org/wiki/Q7259',
      fetched_at: Time.current,
      display_name: 'Ada Lovelace',
      summary: 'English mathematician',
      bio: 'Known for early work on computation.',
      tags: [ 'Mathematics', 'Computing' ],
      affiliations: [ { name: 'Analytical Society', category: 'community' } ]
    }

    with_stubbed_method(ExternalPeople::WikidataClient, :fetch_profile, profile) do
      post person_imports_path, params: { source_name: 'wikidata', external_id: 'Q7259' }
    end

    person = Person.find_by!(display_name: 'Ada Lovelace')
    assert_redirected_to edit_person_path(person)
    assert_empty person.tags
    assert_nil person.primary_affiliation
    assert_equal 'Q7259', person.person_external_profiles.first.external_id
    assert_equal [ 'Mathematics', 'Computing' ], person.person_external_profiles.first.graph_tags
    assert_equal [ 'Analytical Society' ], person.person_external_profiles.first.graph_organizations
    assert_equal [ 'imported' ], person.edit_histories.pluck(:action)
    assert_match 'Wikidata', person.edit_histories.last.summary
  end

  test 'editor can enrich an existing person from an external source' do
    sign_in_as(create_user)

    person = Person.create!(display_name: 'Ada Lovelace', publication_status: 'published')
    profile = {
      source_name: 'openalex',
      external_id: 'A123',
      source_url: 'https://openalex.org/A123',
      fetched_at: Time.current,
      display_name: 'Ada Lovelace',
      summary: 'Research profile',
      bio: 'Imported from OpenAlex',
      tags: [ 'Computation' ],
      affiliations: [ { name: 'Royal Society', category: 'institution' } ]
    }

    with_stubbed_method(ExternalPeople::OpenAlexClient, :fetch_profile, profile) do
      post person_imports_path, params: { source_name: 'openalex', external_id: 'A123', person_id: person.id }
    end

    assert_redirected_to person_path(person)
    assert_equal person.id, PersonExternalProfile.find_by!(external_id: 'A123').person_id
    assert_empty person.reload.tags
    assert_equal [ 'Computation' ], person.person_external_profiles.find_by!(external_id: 'A123').graph_tags
    assert_equal [ 'imported' ], person.edit_histories.pluck(:action)
    assert_match 'OpenAlex', person.edit_histories.last.summary
  end

  test 'person detail resolves lightweight external profiles at render time' do
    person = Person.create!(display_name: 'Ada Lovelace', publication_status: 'published')
    person.person_external_profiles.create!(
      source_name: 'openalex',
      external_id: 'A123',
      source_url: 'https://openalex.org/A123',
      fetched_at: Time.current
    )
    remote_profile = {
      source_name: 'openalex',
      external_id: 'A123',
      source_url: 'https://openalex.org/A123',
      fetched_at: Time.current,
      display_name: 'Ada Lovelace',
      summary: 'University of London / 120 works',
      bio: 'Imported biography',
      tags: [ 'Computing', 'Mathematics' ],
      affiliations: [ { name: 'University of London', category: 'institution', title: 'Researcher' } ]
    }

    with_stubbed_method(ExternalPeople::OpenAlexClient, :fetch_profile, remote_profile) do
      get person_path(person)
    end

    assert_response :success
    assert_match 'University of London', response.body
    assert_match 'Computing', response.body
    assert_match '外部DBを都度参照中', response.body
    assert_match '編集履歴', response.body
  end

  test 'editor only sees wikidata when openalex feature flag is disabled' do
    sign_in_as(create_user)

    with_stubbed_method(TsunagariFeatureFlags, :openalex_enabled?, false) do
      get new_person_import_path
    end

    assert_response :success
    assert_match 'Wikidata', response.body
    assert_no_match 'OpenAlex', response.body
  end

  test 'person detail import CTA follows enabled external sources for editors' do
    sign_in_as(create_user)

    person = Person.create!(display_name: 'Ada Lovelace', publication_status: 'published')

    with_stubbed_method(TsunagariFeatureFlags, :openalex_enabled?, false) do
      get person_path(person)
    end

    assert_response :success
    assert_match 'Wikidataで補う', response.body
    assert_no_match 'OpenAlexで補う', response.body
  end
end
