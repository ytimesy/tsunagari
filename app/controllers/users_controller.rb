class UsersController < ApplicationController
  before_action :set_user, only: :show

  def index
    @query = params[:q].to_s.strip
    @users = base_scope
    @users = apply_search(@users, @query) if @query.present?
    @users = @users.to_a.sort_by { |user| user.profile.display_name.downcase }
  end

  def show
    return if @user.profile.visible_to?(current_user)

    redirect_to users_path, alert: "この人物録は公開されていません。"
  end

  private

  def set_user
    @user = User.includes(profile: :tags).find(params[:id])
  end

  def base_scope
    User.joins(:profile).includes(profile: :tags).merge(Profile.visible_to(current_user)).distinct
  end

  def apply_search(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"

    scope.left_joins(profile: :tags).where(
      "LOWER(profiles.display_name) LIKE :query OR LOWER(profiles.organization) LIKE :query OR LOWER(profiles.role) LIKE :query OR LOWER(tags.name) LIKE :query",
      query: like_query
    ).distinct
  end
end
