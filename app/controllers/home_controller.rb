class HomeController < ApplicationController
  def show
    @published_people_count = Person.published.count
    @published_case_count = EncounterCase.published.count

    if user_signed_in?
      @recent_cases = current_user.edited_encounter_cases.order(updated_at: :desc).limit(5)
      @recent_notes = current_user.research_notes.includes(:person, :encounter_case).order(created_at: :desc).limit(5)
    else
      @featured_cases = EncounterCase.published.order(published_at: :desc, happened_on: :desc, created_at: :desc).limit(3)
    end
  end
end
