class CaseInsight < ApplicationRecord
  INSIGHT_TYPES = %w[enabler barrier lesson turning_point].freeze

  belongs_to :encounter_case

  validates :insight_type, presence: true, inclusion: { in: INSIGHT_TYPES }
  validates :description, presence: true
end
