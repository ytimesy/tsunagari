require "test_helper"

class ExternalPeople::WikidataYoutuberClientTest < ActiveSupport::TestCase
  test "fetches creator profiles from search index and entity summaries" do
    client = ExternalPeople::WikidataYoutuberClient.new
    search_response = {
      "query" => {
        "search" => [
          { "title" => "Q123" },
          { "title" => "Q456" }
        ]
      }
    }
    entity_response = {
      "entities" => {
        "Q123" => {
          "labels" => { "en" => { "value" => "Sample Creator" } },
          "descriptions" => { "en" => { "value" => "Japanese YouTuber" } }
        },
        "Q456" => {
          "labels" => { "ja" => { "value" => "配信者サンプル" } },
          "descriptions" => { "ja" => { "value" => "オンライン配信者" } }
        }
      }
    }

    with_stubbed_method(
      client,
      :fetch_json,
      callable: ->(_url, params: nil, **_options) { params&.[](:action) == "wbgetentities" ? entity_response : search_response }
    ) do
      profiles = client.fetch_people(occupation_qid: "Q17125263", occupation_label: "YouTuber", limit: 2, offset: 40)

      assert_equal 2, profiles.length
      assert_equal "Q123", profiles.first[:external_id]
      assert_equal "Sample Creator", profiles.first[:display_name]
      assert_equal [ "YouTube", "YouTuber" ], profiles.first[:tags]
      assert_equal "https://www.wikidata.org/wiki/Q456", profiles.second[:source_url]
      assert_equal "オンライン配信者", profiles.second[:summary]
    end
  end

  test "builds indexed search query" do
    query = ExternalPeople::WikidataYoutuberClient.new.send(:search_query_for, "Q17125263")

    assert_equal "haswbstatement:P31=Q5 haswbstatement:P106=Q17125263", query
  end
end
