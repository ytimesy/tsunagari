class HomeController < ApplicationController
  def show
    @people_count = Person.count
    @case_count = EncounterCase.count
    @latest_cases = EncounterCase.includes(:case_outcomes).order(updated_at: :desc, happened_on: :desc, created_at: :desc).limit(4)
    @latest_notes = ResearchNote.includes(:person, :encounter_case).order(created_at: :desc).limit(4)
  end
end
