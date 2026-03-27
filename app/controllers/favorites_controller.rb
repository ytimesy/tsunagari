class FavoritesController < ApplicationController
  before_action :require_authentication
  before_action :set_target_user, only: %i[create destroy]

  def index
    @favorites = current_user.favorites.includes(target_user: { profile: :tags }).order(created_at: :desc)
  end

  def create
    favorite = current_user.favorites.build(target_user: @target_user)

    if favorite.save
      redirect_to user_path(@target_user), notice: "注目人物に追加しました。"
    else
      redirect_to user_path(@target_user), alert: favorite.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.favorites.find_by!(target_user: @target_user).destroy
    redirect_to user_path(@target_user), notice: "注目を外しました。"
  end

  private

  def set_target_user
    @target_user = User.find(params[:user_id])
  end
end
