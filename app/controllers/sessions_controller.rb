class SessionsController < ApplicationController
  before_action :redirect_if_authenticated, only: %i[new create]

  def new; end

  def create
    @user = User.find_by(email: session_params[:email].to_s.strip.downcase)

    if @user&.authenticate(session_params[:password]) && @user.active?
      session[:user_id] = @user.id
      redirect_to root_path, notice: "編集画面にログインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが違います。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました。"
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end
