class CaseSource < ApplicationRecord
  belongs_to :encounter_case
  belongs_to :source

  validates :source_id, uniqueness: { scope: :encounter_case_id }
end
