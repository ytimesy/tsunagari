class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?, :can_edit_content?, :admin_user?, :person_destination_path, :encounter_case_destination_path, :saved_people_count, :saved_person?, :saved_person_note

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

  def saved_people_count
    saved_person_ids.size
  end

  def saved_person?(person)
    saved_person_ids.include?(person.id)
  end

  def saved_person_note(person)
    saved_person_notes.fetch(person.id.to_s, '')
  end

  def saved_person_ids
    normalized_ids = Array(session[:saved_person_ids]).filter_map { |value| Integer(value, exception: false) }.uniq
    session[:saved_person_ids] = normalized_ids.last(100)
  end

  def saved_person_notes
    normalized_notes = session[:saved_person_notes].is_a?(Hash) ? session[:saved_person_notes].transform_keys(&:to_s) : {}
    session[:saved_person_notes] = normalized_notes
  end

  def add_saved_person(person)
    session[:saved_person_ids] = (saved_person_ids + [person.id]).uniq.last(100)
  end

  def remove_saved_person(person)
    session[:saved_person_ids] = saved_person_ids - [person.id]
    notes = saved_person_notes
    notes.delete(person.id.to_s)
    session[:saved_person_notes] = notes
  end

  def update_saved_person_note(person, note)
    add_saved_person(person)
    notes = saved_person_notes
    normalized_note = note.to_s.strip.first(280)

    if normalized_note.present?
      notes[person.id.to_s] = normalized_note
    else
      notes.delete(person.id.to_s)
    end

    session[:saved_person_notes] = notes
  end

  def person_destination_path(person)
    return edit_person_path(person) if can_edit_content? && !person.published?

    person_path(person)
  end

  def encounter_case_destination_path(encounter_case)
    return edit_encounter_case_path(encounter_case) if can_edit_content? && !encounter_case.published?

    encounter_case_path(encounter_case)
  end
end
