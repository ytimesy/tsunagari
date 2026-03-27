class EncounterCase < ApplicationRecord
  PUBLICATION_STATUSES = %w[draft review published archived].freeze

  belongs_to :editor_user, class_name: "User", inverse_of: :edited_encounter_cases

  has_many :case_participants, dependent: :destroy
  has_many :people, through: :case_participants

  has_many :case_tags, dependent: :destroy
  has_many :tags, through: :case_tags

  has_many :case_outcomes, dependent: :destroy
  has_many :case_insights, dependent: :destroy

  has_many :case_sources, dependent: :destroy
  has_many :sources, through: :case_sources

  has_many :research_notes, dependent: :nullify

  before_validation :assign_slug

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :publication_status, presence: true, inclusion: { in: PUBLICATION_STATUSES }

  scope :published, -> { where(publication_status: "published") }

  def self.slug_candidate(value)
    value.to_s.parameterize
  end

  def to_param
    slug
  end

  def visible_to?(viewer)
    publication_status == "published" || viewer.present?
  end

  private

  def assign_slug
    base = self.class.slug_candidate(title)
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
