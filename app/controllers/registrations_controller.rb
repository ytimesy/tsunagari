class RegistrationsController < ApplicationController
  before_action :redirect_if_authenticated, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.build_profile(profile_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to profile_path, notice: "編集メンバーを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def profile_params
    params.require(:user).permit(profile: [ :display_name ]).fetch(:profile, {}).to_h.symbolize_keys.reverse_merge(visibility_level: "member")
  end
end
