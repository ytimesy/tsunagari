require "test_helper"

class PersonNeighborhoodGraphBuilderTest < ActiveSupport::TestCase
  test "builds focal edges from resolved metadata when cached graph data is missing" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A1",
      source_url: "https://openalex.org/A1",
      fetched_at: Time.current
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A2",
      source_url: "https://openalex.org/A2",
      fetched_at: Time.current
    )

    payload = PersonNeighborhoodGraphBuilder.new(
      focal_person: ada,
      candidates: [ babbage ],
      depth: 1,
      profile_metadata_by_person_id: {
        ada.id => { tags: [ "Computing" ], organizations: [ "Analytical Society" ] },
        babbage.id => { tags: [ "Computing" ], organizations: [ "Analytical Society" ] }
      }
    ).payload

    assert_equal 2, payload[:nodes].length
    assert_equal 1, payload[:edges].length
    assert_equal "same_organization", payload[:edges].first[:kind]
    assert_match "Analytical Society", payload[:edges].first[:reason]
  end
end
