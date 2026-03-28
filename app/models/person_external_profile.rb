class PersonExternalProfile < ApplicationRecord
  SOURCES = %w[wikidata openalex].freeze

  belongs_to :person

  validates :source_name, presence: true, inclusion: { in: SOURCES }
  validates :external_id, presence: true
  validates :source_url, presence: true
  validates :fetched_at, presence: true
  validates :external_id, uniqueness: { scope: :source_name }

  def cached_graph_tags
    normalized_cached_values("graph_tags")
  end

  def cached_graph_organizations
    normalized_cached_values("graph_organizations")
  end

  private

  def normalized_cached_values(attribute_name)
    return [] unless has_attribute?(attribute_name)

    Array(self[attribute_name]).filter_map do |value|
      term = value.to_s.squish
      term if term.present?
    end
  end
end
