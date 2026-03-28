require "test_helper"

class BoundaryCrossingPeopleImporterTest < ActiveSupport::TestCase
  test "imports unique people across multiple preset queries and summarizes terms" do
    query_profiles = {
      "artificial intelligence medicine" => [
        profile("A1", "Ada Lovelace", tags: [ "Machine learning", "Medicine" ], organization: "Analytical Health Lab"),
        profile("A2", "Grace Hopper", tags: [ "Machine learning", "Clinical informatics" ], organization: "Civic Health Institute")
      ],
      "machine learning healthcare" => [
        profile("A1", "Ada Lovelace", tags: [ "Machine learning", "Medicine" ], organization: "Analytical Health Lab"),
        profile("A3", "Charles Babbage", tags: [ "Healthcare", "Data science" ], organization: "Analytical Health Lab")
      ],
      "clinical informatics machine learning" => [],
      "biomedical data science" => []
    }

    with_stubbed_method(
      ExternalPeople::OpenAlexClient,
      :search_profiles,
      callable: ->(query, limit:) { query_profiles.fetch(query).first(limit) }
    ) do
      summary = BoundaryCrossingPeopleImporter.new(theme: "ai_healthcare", per_query: 4).import!

      assert_equal 1, summary[:themes].length

      result = summary[:themes].first
      assert_equal "AI × 医療", result.theme_label
      assert_equal 3, result.imported_count
      assert_equal 3, result.candidate_count
      assert_equal %w[A1 A2 A3], PersonExternalProfile.order(:external_id).pluck(:external_id)
      assert_equal "Analytical Health Lab", result.top_organizations.first.first
      assert_equal "Machine learning", result.top_tags.first.first
    end
  end

  test "raises on an unknown theme" do
    error = assert_raises(ArgumentError) do
      BoundaryCrossingPeopleImporter.new(theme: "unknown").import!
    end

    assert_match "unknown theme", error.message
  end

  test "filters out non-person looking author records" do
    query_profiles = {
      "civic technology" => [
        profile("A1", "Ada Lovelace", tags: [ "Civic technology" ], organization: "Civic Lab"),
        profile("A2", "Environmental Data Governance Initiative", tags: [ "Public policy" ], organization: "EDGI"),
        profile("A3", "STUDENT SUCCESS PREDICTION IN HIGHER EDUCATION THROUGH MACHINE LEARNING", tags: [ "Education" ], organization: "Open Learning Lab")
      ],
      "public interest technology" => [],
      "digital government" => [],
      "government innovation" => []
    }

    with_stubbed_method(
      ExternalPeople::OpenAlexClient,
      :search_profiles,
      callable: ->(query, limit:) { query_profiles.fetch(query).first(limit) }
    ) do
      summary = BoundaryCrossingPeopleImporter.new(theme: "civic_technology", per_query: 4).import!

      result = summary[:themes].first
      assert_equal 1, result.candidate_count
      assert_equal 1, result.imported_count
      assert_equal [ "Ada Lovelace" ], result.imported_people.map(&:display_name)
    end
  end

  private

  def profile(external_id, display_name, tags:, organization:)
    {
      source_name: "openalex",
      external_id: external_id,
      source_url: "https://openalex.org/#{external_id}",
      fetched_at: Time.current,
      display_name: display_name,
      summary: "",
      bio: "",
      tags: tags,
      affiliations: [ { name: organization, category: "institution" } ]
    }
  end
end
