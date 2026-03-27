class ResearchNotesController < ApplicationController
  before_action :require_authentication

  def create
    @research_note = current_user.research_notes.build(research_note_params)

    if @research_note.save
      redirect_to target_path_for(@research_note), notice: "編集メモを保存しました。"
    else
      redirect_to fallback_target_path, alert: @research_note.errors.full_messages.to_sentence
    end
  end

  private

  def research_note_params
    params.require(:research_note).permit(:person_id, :encounter_case_id, :note_kind, :body).merge(status: "open")
  end

  def target_path_for(note)
    return person_path(note.person) if note.person.present?

    encounter_case_path(note.encounter_case)
  end

  def fallback_target_path
    if params.dig(:research_note, :person_id).present?
      person = Person.find(params[:research_note][:person_id])
      return person_path(person)
    end

    if params.dig(:research_note, :encounter_case_id).present?
      encounter_case = EncounterCase.find(params[:research_note][:encounter_case_id])
      return encounter_case_path(encounter_case)
    end

    root_path
  end
end
