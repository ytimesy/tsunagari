require "test_helper"

class PersonCaseGraphScopeTest < ActiveSupport::TestCase
  test "expands encounter case network by requested depth" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    kay = Person.create!(display_name: "Alan Kay", publication_status: "published")

    direct_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    direct_case.case_participants.create!(person: ada, participation_role: "participant")
    direct_case.case_participants.create!(person: babbage, participation_role: "participant")

    second_hop_case = EncounterCase.create!(title: "Compiler dialogue", publication_status: "published")
    second_hop_case.case_participants.create!(person: babbage, participation_role: "participant")
    second_hop_case.case_participants.create!(person: grace, participation_role: "participant")

    third_hop_case = EncounterCase.create!(title: "Object systems forum", publication_status: "published")
    third_hop_case.case_participants.create!(person: grace, participation_role: "participant")
    third_hop_case.case_participants.create!(person: kay, participation_role: "participant")

    depth_one = PersonCaseGraphScope.new(focal_person: ada, depth: 1).build
    depth_two = PersonCaseGraphScope.new(focal_person: ada, depth: 2).build
    depth_three = PersonCaseGraphScope.new(focal_person: ada, depth: 3).build

    assert_equal [ "Ada Lovelace", "Charles Babbage" ], depth_one[:people].map(&:display_name).sort
    assert_equal [ "Ada Lovelace", "Charles Babbage", "Grace Hopper" ], depth_two[:people].map(&:display_name).sort
    assert_equal [ "Ada Lovelace", "Alan Kay", "Charles Babbage", "Grace Hopper" ], depth_three[:people].map(&:display_name).sort
    assert_equal [ "Analytical exchange", "Compiler dialogue", "Object systems forum" ], depth_three[:encounter_cases].map(&:title).sort
  end
end
