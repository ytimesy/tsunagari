require "test_helper"

class ExternalPeople::WikidataClientTest < ActiveSupport::TestCase
  test "normalizes search results" do
    client = ExternalPeople::WikidataClient.new
    response = {
      "search" => [
        {
          "id" => "Q7259",
          "label" => "Ada Lovelace",
          "description" => "English mathematician",
          "match" => { "language" => "en" }
        }
      ]
    }

    with_stubbed_method(client, :fetch_json, response) do
      results = client.search("Ada Lovelace")

      assert_equal "wikidata", results.first[:source_name]
      assert_equal "Q7259", results.first[:external_id]
      assert_equal "Ada Lovelace", results.first[:display_name]
    end
  end

  test "normalizes a person profile" do
    client = ExternalPeople::WikidataClient.new
    entity_response = {
      "entities" => {
        "Q7259" => {
          "labels" => { "en" => { "value" => "Ada Lovelace" } },
          "descriptions" => { "en" => { "value" => "English mathematician" } },
          "aliases" => { "en" => [ { "value" => "Augusta Ada King" } ] },
          "claims" => {
            "P31" => [ { "mainsnak" => { "datavalue" => { "value" => { "id" => "Q5" } } } } ],
            "P106" => [ { "mainsnak" => { "datavalue" => { "value" => { "id" => "Q170790" } } } } ],
            "P108" => [ { "mainsnak" => { "datavalue" => { "value" => { "id" => "Q123" } } } } ]
          }
        }
      }
    }
    labels_response = {
      "entities" => {
        "Q170790" => { "labels" => { "en" => { "value" => "mathematician" } } },
        "Q123" => { "labels" => { "en" => { "value" => "Analytical Society" } } }
      }
    }

    with_stubbed_method(
      client,
      :fetch_json,
      callable: ->(_url, params: nil) { params&.[](:action) == "wbgetentities" ? labels_response : entity_response }
    ) do
      profile = client.fetch_profile("Q7259")

      assert_equal "Ada Lovelace", profile[:display_name]
      assert_equal [ "mathematician" ], profile[:tags]
      assert_equal "Analytical Society", profile[:affiliations].first[:name]
    end
  end
end
