class SuccessFactor < ApplicationRecord
  belongs_to :encounter_case

  validates :factor_type, presence: true
  validates :description, presence: true
end
