class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.includes(profile: :tags).find_by(id: session[:user_id])
  end

  def user_signed_in?
    current_user.present?
  end

  def require_authentication
    return if user_signed_in?

    redirect_to sign_in_path, alert: "編集するにはログインしてください。"
  end

  def redirect_if_authenticated
    return unless user_signed_in?

    redirect_to profile_path, notice: "すでに編集画面にログインしています。"
  end
end
