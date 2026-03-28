require "application_system_test_case"

class PersonRelationshipGraphTest < ApplicationSystemTestCase
  test "person detail renders the relationship graph" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

    computing = Tag.create!(name: "Computing")
    ada.tags << computing
    babbage.tags << computing

    encounter_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    encounter_case.case_participants.create!(person: ada, participation_role: "participant")
    encounter_case.case_participants.create!(person: babbage, participation_role: "participant")
    encounter_case.case_participants.create!(person: helper, participation_role: "participant")

    visit person_path(ada)

    assert_text "人物関係図"
    assert_selector ".relationship-canvas svg", wait: 5
    assert_selector ".relationship-depth-panel.is-active .relationship-canvas svg line", count: 3, wait: 5
  end

  test "person detail can filter relationship kinds by color button" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

    computing = Tag.create!(name: "Computing")
    ada.tags << computing
    babbage.tags << computing

    encounter_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    encounter_case.case_participants.create!(person: ada, participation_role: "participant")
    encounter_case.case_participants.create!(person: babbage, participation_role: "participant")
    encounter_case.case_participants.create!(person: helper, participation_role: "participant")

    visit person_path(ada)

    assert_selector ".relationship-depth-panel.is-active .relationship-canvas svg line", count: 3, wait: 5

    find("button[data-kind='same_field']").click

    assert_selector ".relationship-depth-panel.is-active .relationship-canvas svg line", count: 2, wait: 5

    click_button "全表示"

    assert_selector ".relationship-depth-panel.is-active .relationship-canvas svg line", count: 3, wait: 5
  end

  test "person detail can switch relationship depth" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")

    direct_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    direct_case.case_participants.create!(person: ada, participation_role: "participant")
    direct_case.case_participants.create!(person: babbage, participation_role: "participant")

    second_hop_case = EncounterCase.create!(title: "Compiler dialogue", publication_status: "published")
    second_hop_case.case_participants.create!(person: babbage, participation_role: "participant")
    second_hop_case.case_participants.create!(person: grace, participation_role: "participant")

    visit person_path(ada)

    assert_text "1階層"
    assert_selector ".relationship-depth-panel.is-active .relationship-canvas svg line", count: 1, wait: 5

    click_button "2階層"

    assert_current_path person_path(ada)
    assert_selector ".relationship-depth-panel.is-active .relationship-canvas svg line", count: 2, wait: 5
  end

  test "three-hop graph keeps person labels visible when the network grows" do
    focal = Person.create!(display_name: "Ada", publication_status: "published")

    first_hop = 7.times.map do |index|
      Person.create!(display_name: "B#{index + 1}", publication_status: "published")
    end
    second_hop = 10.times.map do |index|
      Person.create!(display_name: "C#{index + 1}", publication_status: "published")
    end
    third_hop = 14.times.map do |index|
      Person.create!(display_name: "D#{index + 1}", publication_status: "published")
    end

    first_hop.each_with_index do |person, index|
      encounter_case = EncounterCase.create!(title: "First hop #{index + 1}", publication_status: "published")
      encounter_case.case_participants.create!(person: focal, participation_role: "participant")
      encounter_case.case_participants.create!(person: person, participation_role: "participant")
    end

    second_hop.each_with_index do |person, index|
      encounter_case = EncounterCase.create!(title: "Second hop #{index + 1}", publication_status: "published")
      encounter_case.case_participants.create!(person: first_hop[index % first_hop.length], participation_role: "participant")
      encounter_case.case_participants.create!(person: person, participation_role: "participant")
    end

    third_hop.each_with_index do |person, index|
      encounter_case = EncounterCase.create!(title: "Third hop #{index + 1}", publication_status: "published")
      encounter_case.case_participants.create!(person: second_hop[index % second_hop.length], participation_role: "participant")
      encounter_case.case_participants.create!(person: person, participation_role: "participant")
    end

    visit person_path(focal, graph_depth: 3)

    assert_selector ".relationship-canvas svg text", text: "B1", wait: 5
    assert_selector ".relationship-canvas svg text", text: "D14", wait: 5
  end
end
