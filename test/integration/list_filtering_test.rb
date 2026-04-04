require "test_helper"

class ListFilteringTest < ActionDispatch::IntegrationTest
  test "guest people filters show public records without archived items and ignore the status filter" do
    public_person = Person.create!(display_name: "Public Analyst", publication_status: "published")
    draft_person = Person.create!(display_name: "Draft Analyst", publication_status: "draft")
    archived_person = Person.create!(display_name: "Archived Analyst", publication_status: "archived")
    computing = Tag.create!(name: "Computing")
    public_person.tags << computing
    draft_person.tags << computing
    archived_person.tags << computing

    get people_path, params: { tag: "Computing", publication_status: "draft" }

    assert_response :success
    assert_match "Public Analyst", response.body
    assert_match "Draft Analyst", response.body
    assert_no_match "Archived Analyst", response.body
    assert_match "条件をリセット", response.body
  end

  test "people search matches quality insight fields" do
    Person.create!(
      display_name: "Bridge Strategist",
      publication_status: "published",
      recommended_for: "地域と研究をつなぐ企画設計",
      meeting_value: "行政と研究の橋渡しを相談しやすい人物です。",
      fit_modes: "相談向き, 登壇向き"
    )

    get people_path, params: { q: "橋渡し" }

    assert_response :success
    assert_match "Bridge Strategist", response.body
    assert_match "相談向き", response.body
  end

  test "editor can filter people by status, source presence, and sort" do
    sign_in_as(create_user)

    external_draft = Person.create!(display_name: "External Draft", publication_status: "draft")
    external_draft.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q1",
      source_url: "https://www.wikidata.org/wiki/Q1",
      fetched_at: Time.current
    )
    local_review = Person.create!(display_name: "Local Review", publication_status: "review")
    external_draft.update_columns(updated_at: 3.days.ago)
    local_review.update_columns(updated_at: Time.current)

    get people_path, params: { publication_status: "draft", source_filter: "external" }

    assert_response :success
    assert_match "External Draft", response.body
    assert_no_match "Local Review", response.body

    get people_path, params: { sort: "recently_updated" }

    assert_response :success
    assert_operator response.body.index("Local Review"), :<, response.body.index("External Draft")
  end

  test "youtube guide shows visible people and filters by tag" do
    public_person = Person.create!(display_name: "Public Analyst", publication_status: "published", summary: "動画で紹介しやすい人物です。", fit_modes: "登壇向き")
    archived_person = Person.create!(display_name: "Archived Analyst", publication_status: "archived")
    computing = Tag.create!(name: "Computing")
    public_person.tags << computing
    archived_person.tags << computing

    get youtube_guide_people_path, params: { tag: "Computing" }

    assert_response :success
    assert_match "YouTube人物図鑑", response.body
    assert_match "Public Analyst", response.body
    assert_no_match "Archived Analyst", response.body
    assert_match "Insight", response.body
    assert_match "登壇向き", response.body
  end
end
