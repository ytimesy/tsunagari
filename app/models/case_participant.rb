class CaseParticipant < ApplicationRecord
  belongs_to :encounter_case
  belongs_to :person

  validates :participation_role, presence: true
  validates :person_id, uniqueness: { scope: %i[encounter_case_id participation_role] }
end
