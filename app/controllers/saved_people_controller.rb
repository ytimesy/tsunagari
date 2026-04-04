
require 'csv'

class SavedPeopleController < ApplicationController
  before_action :set_person, only: %i[create destroy update]

  def show
    @saved_people = visible_saved_people
    @hidden_saved_count = [saved_people_count - @saved_people.size, 0].max
  end

  def export
    people = visible_saved_people
    csv = CSV.generate(headers: true) do |rows|
      rows << ['名前', 'URL', '要約', '主な所属', 'タグ', '保存メモ']

      people.each do |person|
        rows << [
          person.display_name,
          view_context.person_destination_path(person),
          person.summary.presence || person.bio.presence || '',
          person.primary_affiliation&.organization&.name.to_s,
          person.tags.order(:name).pluck(:name).join(' / '),
          saved_person_note(person)
        ]
      end
    end

    send_data "﻿#{csv}", filename: "tsunagari-saved-people-#{Date.current.iso8601}.csv", type: 'text/csv; charset=utf-8'
  end

  def create
    add_saved_person(@person)
    redirect_back fallback_location: saved_people_path, notice: '保存リストに追加しました。'
  end

  def update
    update_saved_person_note(@person, params.dig(:saved_person, :note))
    redirect_back fallback_location: saved_people_path, notice: '保存メモを更新しました。'
  end

  def destroy
    remove_saved_person(@person)
    redirect_back fallback_location: saved_people_path, notice: '保存リストから外しました。'
  end

  private

  def set_person
    scope = can_edit_content? ? Person.where.not(publication_status: 'archived') : Person.publicly_visible
    @person = scope.includes(:tags, person_affiliations: :organization).find_by(slug: params[:slug])
    raise ActiveRecord::RecordNotFound if @person.nil?
  end

  def visible_saved_people
    scope = can_edit_content? ? Person.where.not(publication_status: 'archived') : Person.publicly_visible
    loaded = scope.includes(:tags, person_affiliations: :organization).where(id: saved_person_ids).index_by(&:id)
    saved_person_ids.filter_map { |person_id| loaded[person_id] }
  end
end
