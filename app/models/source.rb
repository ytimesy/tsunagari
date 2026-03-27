class Source < ApplicationRecord
  has_many :case_sources, dependent: :destroy
  has_many :encounter_cases, through: :case_sources

  validates :title, presence: true
  validates :url, presence: true, uniqueness: true
end
