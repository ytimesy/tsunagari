require "test_helper"

class PersonGraphMetadataBuilderTest < ActiveSupport::TestCase
  test "collects graph tags from fit modes and insight text" do
    person = Person.create!(
      display_name: "Insightful Researcher",
      publication_status: "published",
      fit_modes: "登壇向き, 相談向き",
      recommended_for: "AI と YouTube の企画設計に向いています。",
      meeting_value: "共同研究の壁打ちにも使えます。"
    )

    metadata = PersonGraphMetadataBuilder.build(person)

    assert_includes metadata[:tags], "登壇向き"
    assert_includes metadata[:tags], "相談向き"
    assert_includes metadata[:tags], "共同研究向き"
    assert_includes metadata[:tags], "AI"
    assert_includes metadata[:tags], "YouTube"
    assert_empty metadata[:organizations]
  end
end
