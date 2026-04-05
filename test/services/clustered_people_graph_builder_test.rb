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
    overlap = builder.selected_cluster_overlap

    assert_equal 2, summary[:cluster_count]
    assert_equal 1, summary[:edge_count]
    assert_equal "cluster_overview", payload[:variant]
    analytical_node = payload[:nodes].find { |node| node[:label] == "Analytical Society" }
    civic_edge = payload[:edges].first

    assert_includes payload[:nodes].map { |node| node[:label] }, "Analytical Society"
    assert_includes payload[:nodes].map { |node| node[:label] }, "Civic Lab"
    assert_equal "organization", analytical_node[:category]
    assert analytical_node[:selected]
    assert_equal 4, civic_edge[:pairCount]
    assert_includes civic_edge[:sharedTags], "Computing"
    assert_equal "Analytical Society", selected_cluster[:label]
    assert_equal 2, selected_cluster[:people_count]
    assert_equal [ "Ada Lovelace", "Charles Babbage" ], selected_cluster[:people].map(&:display_name)
    assert_equal "Civic Lab", overlap[:neighbor_label]
    assert_equal 0, overlap[:overlap_count]
    assert_equal 4, overlap[:union_count]
    assert_equal "disjoint", overlap[:relation_mode]
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

test "falls back to multiple overview clusters when everyone collapses into one dominant cluster" do
  people = 4.times.map do |index|
    person = Person.create!(display_name: format("Creator %02d", index), publication_status: "published")
    person.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q#{index}",
      source_url: "https://www.wikidata.org/wiki/Q#{index}",
      fetched_at: Time.current,
      graph_tags: [ "YouTube" ],
      graph_organizations: [ "Creator Hub" ]
    )
    person
  end

  builder = ClusteredPeopleGraphBuilder.new(people: people)
  payload = builder.payload
  summary = builder.summary

  assert_operator summary[:cluster_count], :>=, 2
  assert_operator payload[:nodes].length, :>=, 2
  assert_includes payload[:nodes].map { |node| node[:label] }, "人物群 1"
  assert_includes payload[:nodes].map { |node| node[:label] }, "人物群 2"
end

  test "builds cluster overview from resolved metadata when lightweight cache is empty" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

    [ [ ada, "A1" ], [ babbage, "A2" ], [ grace, "A3" ], [ helper, "A4" ] ].each do |person, external_id|
      person.person_external_profiles.create!(
        source_name: "openalex",
        external_id: external_id,
        source_url: "https://openalex.org/#{external_id}",
        fetched_at: Time.current
      )
    end

    builder = ClusteredPeopleGraphBuilder.new(
      people: [ ada, babbage, grace, helper ],
      profile_metadata_by_person_id: {
        ada.id => { tags: [ "Computing" ], organizations: [ "Analytical Society" ] },
        babbage.id => { tags: [ "Computing" ], organizations: [ "Analytical Society" ] },
        grace.id => { tags: [ "Computing" ], organizations: [ "Civic Lab" ] },
        helper.id => { tags: [ "Computing", "Civic Design" ], organizations: [ "Civic Lab" ] }
      }
    )

    payload = builder.payload
    summary = builder.summary

    assert_equal 2, summary[:cluster_count]
    assert_equal 1, summary[:edge_count]
    assert_includes payload[:nodes].map { |node| node[:label] }, "Analytical Society"
    assert_includes payload[:nodes].map { |node| node[:label] }, "Civic Lab"
  end

  test "keeps a person graph for large clusters by selecting the most connected members" do
    61.times do |index|
      person = Person.create!(display_name: format("Researcher %02d", index), publication_status: "published")

      person.person_external_profiles.create!(
        source_name: "openalex",
        external_id: "A#{index}",
        source_url: "https://openalex.org/A#{index}",
        fetched_at: Time.current,
        graph_tags: [ "Computing", ("Mathematics" if index < 40), ("Systems" if index.even?) ].compact,
        graph_organizations: [ "Analytical Society", ("Logic Lab" if index < 20) ].compact
      )
    end

    builder = ClusteredPeopleGraphBuilder.new(
      people: Person.order(:display_name).to_a,
      selected_cluster_slug: "org-analytical-society"
    )
    selected_cluster = builder.selected_cluster

    assert_equal 61, selected_cluster[:people_count]
    assert_equal 60, selected_cluster[:graph_people].length
    assert selected_cluster[:graph_truncated]
  end
end
