require "application_system_test_case"

class PeopleGraphNavigationTest < ApplicationSystemTestCase
  test "clicking a node in the global graph opens the person detail page" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")

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

    visit graph_people_path

    assert_text "全体人物関係図"
    assert_selector "[data-node-href='#{person_path(ada)}']", wait: 5

    find("[data-node-href='#{person_path(ada)}']", visible: :all).click

    assert_current_path person_path(ada)
    assert_text "人物概要"
    assert_text "Ada Lovelace"
  end
end
