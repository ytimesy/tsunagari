require "test_helper"

class ClusteredPeopleGraphBuilderTest < ActiveSupport::TestCase
  test "builds cluster overview from imported people metadata" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

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
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q1",
      source_url: "https://www.wikidata.org/wiki/Q1",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Civic Lab" ]
    )
    helper.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q2",
      source_url: "https://www.wikidata.org/wiki/Q2",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Civic Design" ],
      graph_organizations: [ "Civic Lab" ]
    )

    builder = ClusteredPeopleGraphBuilder.new(people: [ ada, babbage, grace, helper ], selected_cluster_slug: "org-analytical-society")
    payload = builder.payload
    summary = builder.summary
    selected_cluster = builder.selected_cluster

    assert_equal 2, summary[:cluster_count]
    assert_equal 1, summary[:edge_count]
    assert_includes payload[:nodes].map { |node| node[:label] }, "Analytical Society"
    assert_includes payload[:nodes].map { |node| node[:label] }, "Civic Lab"
    assert_equal "Analytical Society", selected_cluster[:label]
    assert_equal 2, selected_cluster[:people_count]
    assert_equal [ "Ada Lovelace", "Charles Babbage" ], selected_cluster[:people].map(&:display_name)
  end

  test "builds fallback network clusters for nearby people when dominant tags are too small for main clusters" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A1",
      source_url: "https://openalex.org/A1",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Analytical Society" ]
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A2",
      source_url: "https://openalex.org/A2",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Difference Engine Circle" ]
    )
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q1",
      source_url: "https://www.wikidata.org/wiki/Q1",
      fetched_at: Time.current,
      graph_tags: [ "Compiler Design" ],
      graph_organizations: [ "US Navy" ]
    )
    helper.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q2",
      source_url: "https://www.wikidata.org/wiki/Q2",
      fetched_at: Time.current,
      graph_tags: [ "Compiler Design" ],
      graph_organizations: [ "Civic Lab" ]
    )

    builder = ClusteredPeopleGraphBuilder.new(people: [ ada, babbage, grace, helper ])
    summary = builder.summary
    labels = builder.payload[:nodes].map { |node| node[:label] }

    assert_equal 2, summary[:cluster_count]
    assert_includes labels, "Computing"
    assert_includes labels, "Compiler Design"
    assert_not_includes labels, "その他"
  end
end
