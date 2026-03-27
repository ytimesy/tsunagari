class CaseOutcome < ApplicationRecord
  EVIDENCE_LEVELS = %w[documented reported observed hypothesis].freeze

  belongs_to :encounter_case

  validates :category, presence: true
  validates :description, presence: true
  validates :evidence_level, inclusion: { in: EVIDENCE_LEVELS }, allow_blank: true
end
