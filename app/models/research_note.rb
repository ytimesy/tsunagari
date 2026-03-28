class ResearchNote < ApplicationRecord
  NOTE_KINDS = %w[research hypothesis source_check draft_outline].freeze
  STATUSES = %w[open reviewed archived].freeze

  belongs_to :person, optional: true
  belongs_to :encounter_case, optional: true

  validates :body, presence: true
  validates :note_kind, presence: true, inclusion: { in: NOTE_KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :person_or_encounter_case_must_be_present

  private

  def person_or_encounter_case_must_be_present
    return if person_id.present? || encounter_case_id.present?

    errors.add(:base, "人物または出会い事例を指定してください。")
  end
end
