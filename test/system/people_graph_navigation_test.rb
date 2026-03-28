require "application_system_test_case"

class PeopleGraphNavigationTest < ApplicationSystemTestCase
  test "clicking a cluster node in the global graph opens the cluster detail and person links" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

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
      graph_organizations: [ "Analytical Society" ]
    )
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q111",
      source_url: "https://www.wikidata.org/wiki/Q111",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Civic Lab" ]
    )
    helper.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q789",
      source_url: "https://www.wikidata.org/wiki/Q789",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Civic Design" ],
      graph_organizations: [ "Civic Lab" ]
    )

    visit graph_people_path

    assert_text "全体人物関係図"
    assert_selector "[data-node-href='#{graph_people_path(cluster: "org-analytical-society")}']", wait: 5

    find("[data-node-href='#{graph_people_path(cluster: "org-analytical-society")}']", visible: :all).click

    assert_current_path graph_people_path(cluster: "org-analytical-society"), ignore_query: false
    assert_text "この集団の人物"

    click_link "Ada Lovelace"

    assert_current_path person_path(ada)
    assert_text "人物概要"
    assert_text "Ada Lovelace"
  end
end
