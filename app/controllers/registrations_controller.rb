class RegistrationsController < ApplicationController
  before_action :redirect_if_authenticated, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(role: "editor", status: "active"))

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "編集メンバーを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
