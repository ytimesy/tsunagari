class User < ApplicationRecord
  has_secure_password

  has_one :profile, dependent: :destroy

  has_many :favorites, foreign_key: :owner_user_id, dependent: :destroy, inverse_of: :owner_user
  has_many :favorited_users, through: :favorites, source: :target_user

  has_many :reverse_favorites,
           class_name: "Favorite",
           foreign_key: :target_user_id,
           dependent: :destroy,
           inverse_of: :target_user

  has_many :authored_encounter_notes,
           class_name: "EncounterNote",
           foreign_key: :author_user_id,
           dependent: :destroy,
           inverse_of: :author_user

  has_many :subject_encounter_notes,
           class_name: "EncounterNote",
           foreign_key: :subject_user_id,
           dependent: :destroy,
           inverse_of: :subject_user

  before_validation :normalize_email
  after_create_commit :ensure_profile!

  validates :email, presence: true, uniqueness: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def ensure_profile!
    return if profile.present?

    create_profile!(display_name: email.split("@").first, visibility_level: "member")
  end
end
