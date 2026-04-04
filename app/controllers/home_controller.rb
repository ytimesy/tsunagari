class HomeController < ApplicationController
  def show
    people_scope = can_edit_content? ? Person.where.not(publication_status: 'archived') : Person.publicly_visible

    @people_count = people_scope.count
    @people_status_counts = can_edit_content? ? publication_status_counts_for(Person) : {}
    @quality_people_count = people_scope.where.not(recommended_for: [ nil, "" ]).or(people_scope.where.not(meeting_value: [ nil, "" ])).distinct.count
    @latest_people = people_scope.order(updated_at: :desc, published_at: :desc, created_at: :desc).limit(4)
    @latest_notes = can_edit_content? ? ResearchNote.includes(:person).where.not(person_id: nil).order(created_at: :desc).limit(4) : []
  end

  private

  def publication_status_counts_for(model)
    counts = model.group(:publication_status).count

    model::PUBLICATION_STATUSES.index_with do |status|
      counts.fetch(status, 0)
    end
  end
end
