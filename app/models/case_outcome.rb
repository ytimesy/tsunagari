class CaseOutcome < ApplicationRecord
  EVIDENCE_LEVELS = %w[documented reported observed hypothesis].freeze
  OUTCOME_DIRECTIONS = %w[positive negative mixed unresolved].freeze

  belongs_to :encounter_case

  validates :category, presence: true
  validates :description, presence: true
  validates :outcome_direction, presence: true, inclusion: { in: OUTCOME_DIRECTIONS }
  validates :evidence_level, inclusion: { in: EVIDENCE_LEVELS }, allow_blank: true
end
