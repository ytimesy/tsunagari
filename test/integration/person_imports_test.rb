require "test_helper"

class PersonImportsTest < ActionDispatch::IntegrationTest
  test "visitor can search external people candidates" do
    results = [
      {
        source_name: "wikidata",
        external_id: "Q7259",
        display_name: "Ada Lovelace",
        subtitle: "English mathematician",
        badges: [ "Wikidata" ],
        source_url: "https://www.wikidata.org/wiki/Q7259"
      }
    ]

    with_stubbed_method(ExternalPeople::WikidataClient, :search, results) do
      get new_person_import_path, params: { source_name: "wikidata", q: "Ada Lovelace" }
    end

    assert_response :success
    assert_match "Ada Lovelace", response.body
    assert_match "Wikidata", response.body
    assert_match "人物録へ取り込む", response.body
  end

  test "visitor can import a new person from an external source" do
    profile = {
      source_name: "wikidata",
      external_id: "Q7259",
      source_url: "https://www.wikidata.org/wiki/Q7259",
      fetched_at: Time.current,
      display_name: "Ada Lovelace",
      summary: "English mathematician",
      bio: "Known for early work on computation.",
      tags: [ "Mathematics", "Computing" ],
      affiliations: [ { name: "Analytical Society", category: "community" } ],
      raw_payload: { description: "English mathematician" }
    }

    with_stubbed_method(ExternalPeople::WikidataClient, :fetch_profile, profile) do
      post person_imports_path, params: { source_name: "wikidata", external_id: "Q7259" }
    end

    person = Person.find_by!(display_name: "Ada Lovelace")
    assert_redirected_to person_path(person)
    assert_equal [ "Computing", "Mathematics" ], person.tags.order(:name).pluck(:name)
    assert_equal "Analytical Society", person.primary_affiliation.organization.name
    assert_equal "Q7259", person.person_external_profiles.first.external_id
  end

  test "visitor can enrich an existing person from an external source" do
    person = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    profile = {
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      display_name: "Ada Lovelace",
      summary: "Research profile",
      bio: "Imported from OpenAlex",
      tags: [ "Computation" ],
      affiliations: [ { name: "Royal Society", category: "institution" } ],
      raw_payload: { works_count: 10 }
    }

    with_stubbed_method(ExternalPeople::OpenAlexClient, :fetch_profile, profile) do
      post person_imports_path, params: { source_name: "openalex", external_id: "A123", person_id: person.id }
    end

    assert_redirected_to person_path(person)
    assert_equal person.id, PersonExternalProfile.find_by!(external_id: "A123").person_id
    assert_equal [ "Computation" ], person.reload.tags.order(:name).pluck(:name)
  end
end
