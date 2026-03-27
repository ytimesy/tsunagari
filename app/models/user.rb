class User < ApplicationRecord
  ROLES = %w[editor admin].freeze
  STATUSES = %w[active invited disabled].freeze

  has_secure_password

  has_many :edited_encounter_cases,
           class_name: "EncounterCase",
           foreign_key: :editor_user_id,
           dependent: :restrict_with_exception,
           inverse_of: :editor_user

  has_many :research_notes,
           class_name: "ResearchNote",
           foreign_key: :author_user_id,
           dependent: :destroy,
           inverse_of: :author_user

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  def active?
    status == "active"
  end

  def admin?
    role == "admin"
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
