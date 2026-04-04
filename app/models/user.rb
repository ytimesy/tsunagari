class User < ApplicationRecord
  ROLES = %w[member editor admin].freeze
  STATUSES = %w[active disabled].freeze

  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :password, length: { minimum: 8 }, allow_nil: true

  scope :active, -> { where(status: 'active') }

  def member?
    role == "member"
  end

  def editor?
    role.in?(%w[editor admin])
  end

  def admin?
    role == 'admin'
  end

  def active?
    status == 'active'
  end

  def can_edit_content?
    editor? && active?
  end

  def can_view_deep_insight?
    role.in?(%w[member editor admin]) && active?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
