require "test_helper"

class InsightMembershipTest < ActionDispatch::IntegrationTest
  test "guest sees insight paywall on person detail" do
    person = Person.create!(
      display_name: "Insight Target",
      publication_status: "published",
      recommended_for: "教育と地域実装をつなぐ企画に向いています。",
      meeting_value: "実践知を翻訳しながら次の打ち手を考えられます。",
      fit_modes: "登壇向き, 相談向き",
      introduction_note: "行政と教育現場の間にいる人へ紹介すると噛み合います。"
    )

    get person_path(person)
    assert_response :success
    assert_match "活用視点の全文は Insight で読めます", response.body
    assert_match "仮説の人物像の詳細は Insight で読めます", response.body
    assert_match "利用登録", response.body
    assert_no_match "行政と教育現場の間にいる人へ紹介すると噛み合います。", response.body
  end

  test "member signup unlocks deep insight sections" do
    person = Person.create!(
      display_name: "Unlocked Target",
      publication_status: "published",
      recommended_for: "研究と編集をつなぐ企画に向いています。",
      meeting_value: "概念整理と企画設計を同時に相談できます。",
      fit_modes: "登壇向き, 共同研究向き",
      introduction_note: "研究者と編集者の間をつなぐ紹介が有効です。"
    )

    assert_difference -> { User.count }, 1 do
      post member_signups_path, params: {
        return_to: person_path(person),
        user: {
          email: "member-#{SecureRandom.hex(4)}@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to person_path(person)
    follow_redirect!
    assert_response :success
    assert_match "研究者と編集者の間をつなぐ紹介が有効です。", response.body
    assert_match "仮説の人物像", response.body
    assert_match "Insight", response.body
    assert_equal "member", User.order(:created_at).last.role
  end
end
