class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?, :can_edit_content?, :deep_insight_access?, :admin_user?, :person_destination_path

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.active.find_by(id: session[:user_id])
    session.delete(:user_id) if session[:user_id].present? && @current_user.nil?
    @current_user
  end

  def signed_in?
    current_user.present?
  end

  def can_edit_content?
    current_user&.can_edit_content? || false
  end

  def deep_insight_access?
    current_user&.can_view_deep_insight? || false
  end

  def admin_user?
    current_user&.admin? || false
  end

  def require_editor!
    return if can_edit_content?

    store_requested_location
    redirect_to login_path, alert: '編集するにはログインが必要です。'
  end

  def store_requested_location
    return unless request.get?

    session[:return_to] = request.fullpath
  end

  def pop_requested_location
    session.delete(:return_to)
  end

  def person_destination_path(person)
    return edit_person_path(person) if can_edit_content? && !person.published?

    person_path(person)
  end
end
