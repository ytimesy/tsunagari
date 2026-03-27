class Tag < ApplicationRecord
  has_many :profile_tags, dependent: :destroy
  has_many :profiles, through: :profile_tags

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
