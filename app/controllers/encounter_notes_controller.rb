class EncounterNotesController < ApplicationController
  before_action :require_authentication
  before_action :set_subject_user

  def create
    @encounter_note = current_user.authored_encounter_notes.build(encounter_note_params.merge(subject_user: @subject_user))

    if @encounter_note.save
      redirect_to user_path(@subject_user), notice: "取材メモを保存しました。"
    else
      redirect_to user_path(@subject_user), alert: @encounter_note.errors.full_messages.to_sentence
    end
  end

  private

  def set_subject_user
    @subject_user = User.find(params[:user_id])
  end

  def encounter_note_params
    params.require(:encounter_note).permit(:encountered_on, :encounter_place, :note, :next_action)
  end
end
