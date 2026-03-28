require "test_helper"

class RelationshipGraphBuilderTest < ActiveSupport::TestCase
  test "marks shared tags as similar and unmatched pairs as diverse" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    organizer = Person.create!(display_name: "Community Organizer", publication_status: "published")

    computing = Tag.create!(name: "Computing")
    ada.tags << computing
    babbage.tags << computing

    encounter_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    encounter_case.case_participants.create!(person: ada, participation_role: "participant")
    encounter_case.case_participants.create!(person: babbage, participation_role: "participant")
    encounter_case.case_participants.create!(person: organizer, participation_role: "participant")

    graph = RelationshipGraphBuilder.new(
      people: [ ada, babbage, organizer ],
      encounter_cases: [ encounter_case ],
      focal_person: ada
    ).payload

    similar_edge = graph[:edges].find { |edge| edge[:sourceLabel] == "Ada Lovelace" && edge[:targetLabel] == "Charles Babbage" }
    diverse_edge = graph[:edges].find { |edge| edge[:sourceLabel] == "Ada Lovelace" && edge[:targetLabel] == "Community Organizer" }

    assert_equal "similar", similar_edge[:tone]
    assert_match "共通タグ: Computing", similar_edge[:reason]
    assert_equal "diverse", diverse_edge[:tone]
    assert_equal "所属やタグが異なる組み合わせ", diverse_edge[:reason]
    assert_equal ada.id, graph[:centerId]
  end
end
