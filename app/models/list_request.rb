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
  DEFAULT_PACKAGE_KEY = 'starter_10'.freeze
  PACKAGES = {
    'starter_10' => {
      label: '10人ショートリスト',
      price_label: '3,000円',
      requested_count: 10,
      delivery_format: '一言メモ付き',
      budget_range: '5,000円未満',
      deadline_preference: '1週間以内',
      pitch: 'まず小さく候補を見たい人向けの入口です。',
      payment_env: 'TSUNAGARI_LIST_REQUEST_STARTER_PAYMENT_URL',
      features: [ '候補 10 人', '一言理由つき', '参考 URL つき' ]
    },
    'curated_20' => {
      label: '20人キュレーション',
      price_label: '8,000円',
      requested_count: 20,
      delivery_format: '一言メモ付き',
      budget_range: '5,000〜10,000円',
      deadline_preference: '2週間以内',
      pitch: 'イベントや取材候補をちゃんと比較したい人向けです。',
      payment_env: 'TSUNAGARI_LIST_REQUEST_CURATED_PAYMENT_URL',
      features: [ '候補 20 人', '用途別に整理', '優先度の提案つき' ]
    },
    'custom_research' => {
      label: '調査相談プラン',
      price_label: '要相談',
      requested_count: 30,
      delivery_format: '相談して決めたい',
      budget_range: '相談したい',
      deadline_preference: '相談して決めたい',
      pitch: 'テーマが広い、要件が複雑、人数を相談したい場合の入口です。',
      payment_env: nil,
      features: [ '人数を相談', '目的に合わせて設計', '先に要件確認' ]
    }
  }.freeze

  before_validation :normalize_fields

  validates :requester_name, presence: true
  validates :requester_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :request_theme, presence: true
  validates :package_key, presence: true, inclusion: { in: PACKAGES.keys }
  validates :requested_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES }
  validates :delivery_format, inclusion: { in: DELIVERY_FORMATS }, allow_blank: true
  validates :budget_range, inclusion: { in: BUDGET_RANGES }, allow_blank: true
  validates :deadline_preference, inclusion: { in: DEADLINE_PREFERENCES }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  def self.package_for(package_key)
    PACKAGES.fetch(package_key.to_s, PACKAGES.fetch(DEFAULT_PACKAGE_KEY))
  end

  def self.package_options
    PACKAGES.map { |key, package| [ package[:label], key ] }
  end

  def package_config
    self.class.package_for(package_key)
  end

  def package_label
    package_config[:label]
  end

  def package_price_label
    package_config[:price_label]
  end

  private

  def normalize_fields
    self.requester_name = requester_name.to_s.strip
    self.requester_email = requester_email.to_s.strip.downcase
    self.request_theme = request_theme.to_s.strip
    self.request_purpose = request_purpose.to_s.strip.presence
    self.package_key = package_key.to_s.strip.presence || DEFAULT_PACKAGE_KEY
    self.delivery_format = delivery_format.to_s.strip.presence
    self.budget_range = budget_range.to_s.strip.presence
    self.deadline_preference = deadline_preference.to_s.strip.presence
    self.note = note.to_s.strip.presence
  end
end
