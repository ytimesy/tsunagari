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
end
