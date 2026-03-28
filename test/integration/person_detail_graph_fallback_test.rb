require "test_helper"

class PersonDetailGraphFallbackTest < ActionDispatch::IntegrationTest
  test "imported person detail falls back to metadata relationship graph" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    helper = Person.create!(display_name: "Grace Hopper", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Mathematics" ],
      graph_organizations: [ "Analytical Society" ]
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A456",
      source_url: "https://openalex.org/A456",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Analytical Society" ]
    )
    helper.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q789",
      source_url: "https://www.wikidata.org/wiki/Q789",
      fetched_at: Time.current,
      graph_tags: [ "Programming Languages" ],
      graph_organizations: [ "US Navy" ]
    )

    get person_path(ada)

    assert_response :success
    assert_match "人物関係図", response.body
    assert_match "charles-babbage", response.body
    assert_match "共通所属: Analytical Society", response.body
  end

  test "metadata fallback can expand to second hop" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Analytical Society" ]
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A456",
      source_url: "https://openalex.org/A456",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Naval Analytics" ]
    )
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q789",
      source_url: "https://www.wikidata.org/wiki/Q789",
      fetched_at: Time.current,
      graph_tags: [ "Programming Languages" ],
      graph_organizations: [ "Naval Analytics" ]
    )

    get person_path(ada)
    assert_response :success
    assert_match "grace-hopper", response.body
    assert_match 'data-relationship-depth-active-depth-value="1"', response.body
    assert_match(/data-depth="2"\s+hidden/, response.body)
    assert_match "2階層", response.body

    get person_path(ada, graph_depth: 2)
    assert_response :success
    assert_match 'data-relationship-depth-active-depth-value="2"', response.body
  end
end
