class HomeController < ApplicationController
  def show
    people_scope = can_edit_content? ? Person.where.not(publication_status: 'archived') : Person.publicly_visible
    case_scope = can_edit_content? ? EncounterCase.where.not(publication_status: 'archived') : EncounterCase.publicly_visible

    @people_count = people_scope.count
    @case_count = case_scope.count
    @people_status_counts = can_edit_content? ? publication_status_counts_for(Person) : {}
    @case_status_counts = can_edit_content? ? publication_status_counts_for(EncounterCase) : {}
    @latest_cases = case_scope.includes(:case_outcomes).order(updated_at: :desc, happened_on: :desc, created_at: :desc).limit(4)
    @latest_notes = can_edit_content? ? ResearchNote.includes(:person, :encounter_case).order(created_at: :desc).limit(4) : []
  end

  private

  def publication_status_counts_for(model)
    counts = model.group(:publication_status).count

    model::PUBLICATION_STATUSES.index_with do |status|
      counts.fetch(status, 0)
    end
  end
end
