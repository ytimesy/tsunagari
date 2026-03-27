class PersonTag < ApplicationRecord
  belongs_to :person
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :person_id }
end
