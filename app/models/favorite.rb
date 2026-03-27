class Favorite < ApplicationRecord
  belongs_to :owner_user, class_name: "User", inverse_of: :favorites
  belongs_to :target_user, class_name: "User", inverse_of: :reverse_favorites

  validates :target_user_id, uniqueness: { scope: :owner_user_id }
  validate :owner_and_target_must_differ

  private

  def owner_and_target_must_differ
    return if owner_user_id.blank? || target_user_id.blank?
    return unless owner_user_id == target_user_id

    errors.add(:target_user_id, "must be different from owner_user_id")
  end
end
