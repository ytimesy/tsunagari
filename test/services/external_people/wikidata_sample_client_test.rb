require "test_helper"

class ExternalPeople::WikidataSampleClientTest < ActiveSupport::TestCase
  test "normalizes bulk wikidata rows into importable profiles" do
    client = ExternalPeople::WikidataSampleClient.new
    response = {
      "results" => {
        "bindings" => [
          {
            "person" => { "value" => "https://www.wikidata.org/entity/Q7259" },
            "personLabel" => { "value" => "Ada Lovelace" },
            "description" => { "value" => "English mathematician" },
            "occupations" => { "value" => "mathematician|writer" },
            "employers" => { "value" => "Analytical Society|Royal Society" }
          }
        ]
      }
    }

    with_stubbed_method(client, :fetch_json, response) do
      profiles = client.fetch_people(limit: 1)

      assert_equal 1, profiles.length
      assert_equal "Q7259", profiles.first[:external_id]
      assert_equal [ "mathematician", "writer" ], profiles.first[:tags]
      assert_equal "Analytical Society", profiles.first[:affiliations].first[:name]
    end
  end
end
