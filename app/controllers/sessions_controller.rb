class SessionsController < ApplicationController
  def new
    redirect_to root_path, notice: 'すでにログインしています。' if signed_in?
  end

  def create
    @email = params[:email].to_s.strip.downcase
    user = User.find_by(email: @email)

    if user&.authenticate(params[:password].to_s) && user.active?
      session[:user_id] = user.id
      redirect_to pop_requested_location.presence || root_path, notice: 'ログインしました。'
    else
      flash.now[:alert] = user.present? && !user.active? ? 'このアカウントは現在利用できません。' : 'メールアドレスまたはパスワードが違います。'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'ログアウトしました。'
  end
end
