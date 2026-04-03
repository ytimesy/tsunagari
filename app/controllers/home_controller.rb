class HomeController < ApplicationController
  def show
    @people_count = Person.published.count
    @case_count = EncounterCase.published.count
    @latest_cases = EncounterCase.published.includes(:case_outcomes).order(updated_at: :desc, happened_on: :desc, created_at: :desc).limit(4)
    @latest_notes = can_edit_content? ? ResearchNote.includes(:person, :encounter_case).order(created_at: :desc).limit(4) : []
  end
end
