class HomeController < ApplicationController
  def show
    people_scope = can_edit_content? ? Person.where.not(publication_status: 'archived') : Person.publicly_visible
    case_scope = can_edit_content? ? EncounterCase.where.not(publication_status: 'archived') : EncounterCase.publicly_visible

    @people_count = people_scope.count
    @case_count = case_scope.count
    @latest_cases = case_scope.includes(:case_outcomes).order(updated_at: :desc, happened_on: :desc, created_at: :desc).limit(4)
    @latest_notes = can_edit_content? ? ResearchNote.includes(:person, :encounter_case).order(created_at: :desc).limit(4) : []
  end
end
