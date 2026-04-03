require "test_helper"

class ExternalPeople::ProviderRegistryTest < ActiveSupport::TestCase
  test "lists wikidata and openalex when openalex is enabled" do
    with_stubbed_method(TsunagariFeatureFlags, :openalex_enabled?, true) do
      assert_equal ["wikidata", "openalex"], ExternalPeople::ProviderRegistry.available_sources
      assert_equal ExternalPeople::OpenAlexClient, ExternalPeople::ProviderRegistry.provider_for("openalex")
    end
  end

  test "excludes openalex when the feature flag is disabled" do
    with_stubbed_method(TsunagariFeatureFlags, :openalex_enabled?, false) do
      assert_equal ["wikidata"], ExternalPeople::ProviderRegistry.available_sources
      error = assert_raises(ExternalPeople::Error) do
        ExternalPeople::ProviderRegistry.provider_for("openalex")
      end

      assert_match "OpenAlex は現在無効です", error.message
    end
  end
end
