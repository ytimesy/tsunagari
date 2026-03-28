class Person < ApplicationRecord
  PUBLICATION_STATUSES = %w[draft review published archived].freeze

  has_many :person_affiliations, dependent: :destroy
  has_many :organizations, through: :person_affiliations

  has_many :person_tags, dependent: :destroy
  has_many :tags, through: :person_tags

  has_many :case_participants, dependent: :destroy
  has_many :encounter_cases, through: :case_participants

  has_many :research_notes, dependent: :nullify

  before_validation :assign_slug

  validates :display_name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :publication_status, presence: true, inclusion: { in: PUBLICATION_STATUSES }

  scope :published, -> { where(publication_status: "published") }

  def self.slug_candidate(value)
    value.to_s.parameterize
  end

  def to_param
    slug
  end

  def visible_to?(_viewer = nil)
    true
  end

  def primary_affiliation
    person_affiliations.find_by(primary_flag: true) || person_affiliations.first
  end

  private

  def assign_slug
    base = self.class.slug_candidate(display_name)
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
