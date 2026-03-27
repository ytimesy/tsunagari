class Organization < ApplicationRecord
  has_many :person_affiliations, dependent: :destroy
  has_many :people, through: :person_affiliations

  before_validation :assign_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def self.slug_candidate(value)
    value.to_s.parameterize
  end

  def to_param
    slug
  end

  private

  def assign_slug
    base = self.class.slug_candidate(name)
    return if base.blank?

    candidate = base
    suffix = 2

    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
