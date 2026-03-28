class EditHistory < ApplicationRecord
  ACTIONS = %w[created updated imported].freeze

  belongs_to :item, polymorphic: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :summary, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
