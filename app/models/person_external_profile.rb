class PersonExternalProfile < ApplicationRecord
  SOURCES = %w[wikidata openalex].freeze

  belongs_to :person

  validates :source_name, presence: true, inclusion: { in: SOURCES }
  validates :external_id, presence: true
  validates :source_url, presence: true
  validates :fetched_at, presence: true
  validates :external_id, uniqueness: { scope: :source_name }
end
