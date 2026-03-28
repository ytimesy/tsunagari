require "test_helper"

class ExternalPeople::OpenAlexClientTest < ActiveSupport::TestCase
  test "normalizes search results" do
    client = ExternalPeople::OpenAlexClient.new
    response = {
      "results" => [
        {
          "id" => "https://openalex.org/A123",
          "display_name" => "Geoffrey Hinton",
          "works_count" => 120,
          "last_known_institutions" => [ { "display_name" => "University of Toronto" } ]
        }
      ]
    }

    with_stubbed_method(client, :fetch_json, response) do
      results = client.search("Geoffrey Hinton")

      assert_equal "openalex", results.first[:source_name]
      assert_equal "A123", results.first[:external_id]
      assert_match "University of Toronto", results.first[:subtitle]
    end
  end

  test "normalizes a profile" do
    client = ExternalPeople::OpenAlexClient.new
    response = {
      "id" => "https://openalex.org/A123",
      "display_name" => "Geoffrey Hinton",
      "display_name_alternatives" => [ "G. Hinton" ],
      "works_count" => 120,
      "cited_by_count" => 5000,
      "orcid" => "https://orcid.org/0000-0001",
      "last_known_institutions" => [
        {
          "display_name" => "University of Toronto",
          "homepage_url" => "https://utoronto.ca"
        }
      ],
      "x_concepts" => [
        { "display_name" => "Machine learning", "score" => 0.9 },
        { "display_name" => "Neural networks", "score" => 0.8 }
      ]
    }

    with_stubbed_method(client, :fetch_json, response) do
      profile = client.fetch_profile("A123")

      assert_equal "Geoffrey Hinton", profile[:display_name]
      assert_equal [ "Machine learning", "Neural networks" ], profile[:tags]
      assert_equal "University of Toronto", profile[:affiliations].first[:name]
    end
  end

  test "normalizes top people list" do
    client = ExternalPeople::OpenAlexClient.new
    response = {
      "results" => [
        {
          "id" => "https://openalex.org/A123",
          "display_name" => "Geoffrey Hinton",
          "works_count" => 120,
          "cited_by_count" => 5000,
          "last_known_institutions" => [
            { "display_name" => "University of Toronto", "homepage_url" => "https://utoronto.ca" }
          ],
          "x_concepts" => [
            { "display_name" => "Machine learning", "score" => 0.9 }
          ]
        }
      ]
    }

    with_stubbed_method(client, :fetch_json, response) do
      profiles = client.fetch_top_people(limit: 1)

      assert_equal 1, profiles.length
      assert_equal "A123", profiles.first[:external_id]
      assert_equal [ "Machine learning" ], profiles.first[:tags]
    end
  end
end
