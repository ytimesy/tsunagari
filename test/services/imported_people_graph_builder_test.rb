require "test_helper"

class ImportedPeopleGraphBuilderTest < ActiveSupport::TestCase
  test "builds a network from cached external metadata" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    curie = Person.create!(display_name: "Marie Curie", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A1",
      source_url: "https://openalex.org/A1",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Mathematics" ],
      graph_organizations: [ "Analytical Society" ]
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A2",
      source_url: "https://openalex.org/A2",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Analytical Society" ]
    )
    curie.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q1",
      source_url: "https://wikidata.org/wiki/Q1",
      fetched_at: Time.current,
      graph_tags: [ "Physics" ],
      graph_organizations: [ "Sorbonne University" ]
    )

    graph = ImportedPeopleGraphBuilder.new(people: [ ada, babbage, curie ])
    payload = graph.payload
    summary = graph.summary

    similar_edge = payload[:edges].find { |edge| edge[:sourceLabel] == "Ada Lovelace" && edge[:targetLabel] == "Charles Babbage" }

    assert_equal 3, payload[:nodes].length
    assert_equal "similar", similar_edge[:tone]
    assert_equal "same_organization", similar_edge[:kind]
    assert_match "共通所属: Analytical Society", similar_edge[:reason]
    assert_equal 2, summary[:connected_people_count]
    assert_equal 1, summary[:isolated_people_count]
    assert_equal [ [ "Analytical Society", 2 ] ], summary[:top_organizations].first(1)
  end
end
