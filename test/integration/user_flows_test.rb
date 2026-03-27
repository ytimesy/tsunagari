require "test_helper"

class UserFlowsTest < ActionDispatch::IntegrationTest
  test "user can sign up, edit profile, and browse app" do
    get sign_up_path
    assert_response :success

    post sign_up_path, params: {
      user: {
        email: "owner@example.com",
        password: "password",
        password_confirmation: "password",
        profile: {
          display_name: "Owner"
        }
      }
    }

    assert_redirected_to profile_path
    follow_redirect!
    assert_response :success
    assert_equal "owner@example.com", User.last.email
    assert_equal "Owner", User.last.profile.display_name

    patch profile_path, params: {
      profile: {
        display_name: "Owner Updated",
        organization: "OpenAI",
        role: "Builder",
        bio: "Builds Tsunagari",
        visibility_level: "member",
        tag_list: "Rails, Community"
      }
    }

    assert_redirected_to profile_path
    follow_redirect!
    assert_match "Owner Updated", response.body

    get users_path
    assert_response :success
  end

  test "guest can browse the public directory while signed-in user sees member profile" do
    public_user = create_user_with_profile(email: "public@example.com", display_name: "Public User", visibility_level: "public")
    member_user = create_user_with_profile(email: "member@example.com", display_name: "Member User", visibility_level: "member")
    private_user = create_user_with_profile(email: "private@example.com", display_name: "Private User", visibility_level: "private")

    get users_path
    assert_response :success
    assert_match "Public User", response.body
    refute_match "Member User", response.body
    refute_match "Private User", response.body

    get user_path(public_user)
    assert_response :success

    get user_path(member_user)
    assert_redirected_to users_path

    sign_in_as(create_user_with_profile(email: "viewer@example.com", display_name: "Viewer", visibility_level: "member"))

    get users_path
    assert_response :success
    assert_match "Member User", response.body
    refute_match "Private User", response.body

    get user_path(member_user)
    assert_response :success

    get user_path(private_user)
    assert_redirected_to users_path
  end

  test "signed-in user can favorite another user and create encounter note" do
    owner = create_user_with_profile(email: "owner2@example.com", display_name: "Owner Two", visibility_level: "member")
    target = create_user_with_profile(email: "target@example.com", display_name: "Target User", visibility_level: "member")

    sign_in_as(owner)

    post user_favorite_path(target)
    assert_redirected_to user_path(target)
    assert_equal 1, owner.favorites.count

    post user_encounter_notes_path(target), params: {
      encounter_note: {
        encountered_on: Date.current,
        encounter_place: "Tokyo",
        note: "Met at a meetup",
        next_action: "Say hello next week"
      }
    }

    assert_redirected_to user_path(target)
    assert_equal 1, owner.authored_encounter_notes.count
  end

  private

  def create_user_with_profile(email:, display_name:, visibility_level:)
    User.create!(
      email: email,
      password: "password",
      password_confirmation: "password",
      profile: Profile.new(display_name: display_name, visibility_level: visibility_level)
    )
  end

  def sign_in_as(user)
    post sign_in_path, params: {
      session: {
        email: user.email,
        password: "password"
      }
    }
  end
end
