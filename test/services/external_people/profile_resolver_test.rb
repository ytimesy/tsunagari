require "test_helper"

class ExternalPeople::ProfileResolverTest < ActiveSupport::TestCase
  test "prefers remote profile data while preserving local overlays" do
    person = Person.create!(
      display_name: "Ada Lovelace",
      summary: "Local summary",
      publication_status: "published"
    )
    person.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current
    )
    person.tags << Tag.create!(name: "Manual Tag")

    remote_profile = {
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      display_name: "Ada Lovelace",
      summary: "Remote summary",
      bio: "Remote biography",
      tags: [ "Computing" ],
      affiliations: [ { name: "University of London", category: "institution" } ]
    }

    resolver = ExternalPeople::ProfileResolver.new

    with_stubbed_method(ExternalPeople::OpenAlexClient, :fetch_profile, remote_profile) do
      resolved = resolver.resolve(person)

      assert_equal "Local summary", resolved[:summary]
      assert_equal "Remote biography", resolved[:bio]
      assert_equal [ "Manual Tag" ], resolved[:tags]
      assert_equal "University of London", resolved[:affiliations].first[:name]
      assert_equal "live", resolved[:source_mode]
    end
  end

  test "builds metadata index keyed by person id" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current
    )
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q11641",
      source_url: "https://www.wikidata.org/wiki/Q11641",
      fetched_at: Time.current
    )

    resolver = ExternalPeople::ProfileResolver.new

    with_stubbed_method(ExternalPeople::OpenAlexClient, :fetch_profile, {
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      display_name: "Ada Lovelace",
      tags: [ "Computing" ],
      affiliations: [ { name: "Analytical Society", category: "institution" } ]
    }) do
      with_stubbed_method(ExternalPeople::WikidataClient, :fetch_profile, {
        source_name: "wikidata",
        external_id: "Q11641",
        source_url: "https://www.wikidata.org/wiki/Q11641",
        fetched_at: Time.current,
        display_name: "Grace Hopper",
        tags: [ "Programming Languages" ],
        affiliations: [ { name: "US Navy", category: "organization" } ]
      }) do
        metadata_index = resolver.metadata_index_for([ ada, grace ])

        assert_equal [ "Computing" ], metadata_index.fetch(ada.id)[:tags]
        assert_equal [ "Analytical Society" ], metadata_index.fetch(ada.id)[:organizations]
        assert_equal [ "Programming Languages" ], metadata_index.fetch(grace.id)[:tags]
        assert_equal [ "US Navy" ], metadata_index.fetch(grace.id)[:organizations]
      end
    end
  end
end
