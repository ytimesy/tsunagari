class Tag < ApplicationRecord
  has_many :person_tags, dependent: :destroy
  has_many :people, through: :person_tags

  has_many :case_tags, dependent: :destroy
  has_many :encounter_cases, through: :case_tags

  before_validation :normalize_name_fields

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true

  private

  def normalize_name_fields
    stripped_name = name.to_s.strip

    self.name = stripped_name if stripped_name.present?
    self.normalized_name = stripped_name.downcase if stripped_name.present?
  end
end
