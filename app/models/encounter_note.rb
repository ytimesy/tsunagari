class EncounterNote < ApplicationRecord
  belongs_to :author_user, class_name: "User", inverse_of: :authored_encounter_notes
  belongs_to :subject_user, class_name: "User", inverse_of: :subject_encounter_notes

  validates :note, presence: true
end
