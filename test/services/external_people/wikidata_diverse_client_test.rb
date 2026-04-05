require "test_helper"

class ExternalPeople::WikidataDiverseClientTest < ActiveSupport::TestCase
  test "normalizes genre-based wikidata rows into importable profiles" do
    client = ExternalPeople::WikidataDiverseClient.new
    search_response = {
      "query" => {
        "search" => [
          { "title" => "Q7259" }
        ]
      }
    }
    entity_response = {
      "entities" => {
        "Q7259" => {
          "labels" => { "en" => { "value" => "Ada Lovelace" } },
          "descriptions" => { "en" => { "value" => "English mathematician" } }
        }
      }
    }

    with_stubbed_method(
      client,
      :fetch_json,
      callable: ->(_url, params: nil, **_options) { params&.[](:action) == "wbgetentities" ? entity_response : search_response }
    ) do
      profiles = client.fetch_people_for_preset(preset_key: "science", limit: 1)

      assert_equal 1, profiles.length
      assert_equal "Q7259", profiles.first[:external_id]
      assert_equal [ "科学", "scientist" ], profiles.first[:tags]
      assert_match "English mathematician", profiles.first[:bio]
    end
  end

  test "builds indexed search query for occupations" do
    query = ExternalPeople::WikidataDiverseClient.new.send(:search_query_for, "Q82955")

    assert_equal "haswbstatement:P31=Q5 haswbstatement:P106=Q82955", query
  end
end
