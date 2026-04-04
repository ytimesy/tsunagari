require "test_helper"

class PersonPublicEstimateBuilderTest < ActiveSupport::TestCase
  test "builds a safe public estimate from tags, roles, and network signals" do
    ada = Person.create!(
      display_name: "Ada Lovelace",
      publication_status: "published",
      recommended_for: "技術史と編集の接点を考える企画",
      fit_modes: "登壇向き, 共同研究向き"
    )
    computing = Tag.create!(name: "Computing")
    ada.tags << computing

    organization = Organization.create!(slug: "analytical-society", name: "Analytical Society", category: "community")
    ada.person_affiliations.create!(organization: organization, title: "Researcher", primary_flag: true)

    builder = PersonPublicEstimateBuilder.new(
      person: ada,
      resolved_profile: {
        tags: ["Computing", "Writing"],
        affiliations: [ { name: "Analytical Society", title: "Researcher" } ]
      },
      navigation_lens: {
        primary_people: [ { label: "Charles Babbage" } ],
        bridge_people: [ { label: "Community Organizer" } ]
      }
    )

    estimate = builder.build

    assert_includes estimate[:roles], "Researcher"
    assert_includes estimate[:roles], "研究・分析寄り"
    assert_includes estimate[:themes], "Computing"
    assert_equal "橋渡し型", estimate.dig(:network_position, :label)
    assert_match "性格や年収", estimate[:notice]
    assert_equal "AL", estimate.dig(:persona_sketch, :visual, :initials)
    assert_match "仮説スケッチ", estimate.dig(:persona_sketch, :notice)
    assert estimate[:evidence].any? { |point| point.include?("主要関係者") }
    assert_equal 5, estimate.dig(:capability_profile, :metrics).length
    assert_equal "分析性", estimate.dig(:capability_profile, :metrics, 0, :label)
    assert_operator estimate.dig(:capability_profile, :metrics, 0, :value), :>=, 3
  end
end
