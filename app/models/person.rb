class Person < ApplicationRecord
  PUBLICATION_STATUSES = %w[draft review published archived].freeze
  QUALITY_TEXT_ATTRIBUTES = %i[recommended_for meeting_value fit_modes introduction_note].freeze

  has_many :person_affiliations, dependent: :destroy
  has_many :organizations, through: :person_affiliations

  has_many :person_tags, dependent: :destroy
  has_many :tags, through: :person_tags

  has_many :person_external_profiles, dependent: :destroy
  has_many :edit_histories, as: :item, dependent: :destroy

  has_many :case_participants, dependent: :destroy
  has_many :encounter_cases, through: :case_participants

  has_many :research_notes, dependent: :nullify

  before_validation :normalize_quality_fields
  before_validation :assign_slug

  validates :display_name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :publication_status, presence: true, inclusion: { in: PUBLICATION_STATUSES }

  scope :published, -> { where(publication_status: 'published') }
  scope :publicly_visible, -> { TsunagariFeatureFlags.strict_public_visibility? ? where(publication_status: 'published') : where.not(publication_status: 'archived') }

  def self.slug_candidate(value)
    parameterized = value.to_s.parameterize
    return parameterized if parameterized.present?

    encoded = value.to_s.unpack1('H*').to_s.first(20)
    encoded.present? ? "person-#{encoded}" : ''
  end

  def to_param
    slug
  end

  def published?
    publication_status == 'published'
  end

  def publicly_visible?
    TsunagariFeatureFlags.strict_public_visibility? ? published? : publication_status != 'archived'
  end

  def visible_to?(viewer = nil)
    publicly_visible? || viewer&.can_edit_content?
  end

  def primary_affiliation
    person_affiliations.find_by(primary_flag: true) || person_affiliations.first
  end

  def primary_external_profile
    person_external_profiles.min_by do |profile|
      [
        profile.source_name == 'openalex' ? 0 : 1,
        -profile.fetched_at.to_i
      ]
    end
  end

  def fit_modes_list
    fit_modes.to_s.split(/[
,、]/).filter_map { |value| value.strip.presence }.uniq
  end

  def quality_insight?
    recommended_for.present? || meeting_value.present? || introduction_note.present? || last_reviewed_on.present? || fit_modes_list.any?
  end

  def quality_summary
    recommended_for.presence || meeting_value.presence || summary.presence || bio.presence
  end

  private

  def normalize_quality_fields
    QUALITY_TEXT_ATTRIBUTES.each do |attribute_name|
      value = public_send(attribute_name)
      public_send("#{attribute_name}=", value.to_s.strip.presence)
    end

    self.fit_modes = fit_modes_list.join(', ').presence
  end

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
