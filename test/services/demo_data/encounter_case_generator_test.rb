require "test_helper"

class DemoData::EncounterCaseGeneratorTest < ActiveSupport::TestCase
  test "generates published demo cases with mixed relationship tones" do
    harvard = Organization.create!(name: "Harvard University")
    mit = Organization.create!(name: "MIT")

    ai = Tag.create!(name: "AI")
    policy = Tag.create!(name: "Policy")

    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "draft")
    alan = Person.create!(display_name: "Alan Turing", publication_status: "draft")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "draft")

    ada.person_affiliations.create!(organization: harvard, primary_flag: true)
    alan.person_affiliations.create!(organization: harvard, primary_flag: true)
    grace.person_affiliations.create!(organization: mit, primary_flag: true)

    ada.tags << ai
    alan.tags << ai
    grace.tags << policy

    encounter_cases = DemoData::EncounterCaseGenerator.generate!(limit: 1)
    encounter_case = encounter_cases.first

    assert_equal 1, encounter_cases.length
    assert_equal "published", encounter_case.publication_status
    assert_match(/\Aデモ事例 1:/, encounter_case.title)
    assert_includes encounter_case.tags.pluck(:name), "デモ"
    assert_equal 3, encounter_case.people.count
    assert encounter_case.case_outcomes.exists?
    assert encounter_case.case_insights.exists?
    assert encounter_case.sources.exists?
    assert encounter_case.research_notes.exists?

    graph = RelationshipGraphBuilder.new(
      people: encounter_case.people,
      encounter_cases: [ encounter_case ]
    ).payload

    assert_includes graph[:edges].pluck(:tone), "similar"
    assert_includes graph[:edges].pluck(:tone), "diverse"
    assert_equal %w[published published published], encounter_case.people.order(:display_name).pluck(:publication_status)
  end
end
