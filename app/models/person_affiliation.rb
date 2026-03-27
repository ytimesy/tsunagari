class PersonAffiliation < ApplicationRecord
  belongs_to :person
  belongs_to :organization

  validates :person_id, uniqueness: { scope: %i[organization_id title started_on] }
end
