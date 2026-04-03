class ListRequest < ApplicationRecord
  STATUSES = %w[new reviewing paid researching delivered archived].freeze
  PAYMENT_STATUSES = %w[pending paid refunded not_required].freeze
  DELIVERY_FORMATS = [
    '一覧だけほしい',
    '一言メモ付き',
    '相談して決めたい'
  ].freeze
  BUDGET_RANGES = [
    '5,000円未満',
    '5,000〜10,000円',
    '10,000〜30,000円',
    '相談したい'
  ].freeze
  DEADLINE_PREFERENCES = [
    '急ぎ',
    '1週間以内',
    '2週間以内',
    '相談して決めたい'
  ].freeze

  before_validation :normalize_fields

  validates :requester_name, presence: true
  validates :requester_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :request_theme, presence: true
  validates :requested_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES }
  validates :delivery_format, inclusion: { in: DELIVERY_FORMATS }, allow_blank: true
  validates :budget_range, inclusion: { in: BUDGET_RANGES }, allow_blank: true
  validates :deadline_preference, inclusion: { in: DEADLINE_PREFERENCES }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  private

  def normalize_fields
    self.requester_name = requester_name.to_s.strip
    self.requester_email = requester_email.to_s.strip.downcase
    self.request_theme = request_theme.to_s.strip
    self.request_purpose = request_purpose.to_s.strip.presence
    self.delivery_format = delivery_format.to_s.strip.presence
    self.budget_range = budget_range.to_s.strip.presence
    self.deadline_preference = deadline_preference.to_s.strip.presence
    self.note = note.to_s.strip.presence
  end
end
