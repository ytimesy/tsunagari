class HomeController < ApplicationController
  def show
    return unless user_signed_in?

    @favorite_users = current_user.favorited_users.includes(:profile).limit(5)
    @recent_notes = current_user.authored_encounter_notes.includes(subject_user: :profile).order(created_at: :desc).limit(5)
  end
end
