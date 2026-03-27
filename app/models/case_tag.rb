class CaseTag < ApplicationRecord
  belongs_to :encounter_case
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :encounter_case_id }
end
