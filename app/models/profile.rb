class Profile < ApplicationRecord
  VISIBILITY_LEVELS = %w[public member private].freeze

  belongs_to :user

  has_many :profile_tags, dependent: :destroy
  has_many :tags, through: :profile_tags

  validates :display_name, presence: true
  validates :visibility_level, presence: true, inclusion: { in: VISIBILITY_LEVELS }

  scope :visible_to, lambda { |viewer|
    if viewer
      where(visibility_level: %w[public member]).or(where(user_id: viewer.id))
    else
      where(visibility_level: "public")
    end
  }

  def visible_to?(viewer)
    return true if visibility_level == "public"
    return viewer.present? if visibility_level == "member"

    viewer&.id == user_id
  end
end
