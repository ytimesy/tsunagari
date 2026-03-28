require "test_helper"

class ExternalPeople::ImporterTest < ActiveSupport::TestCase
  test "creates a person, affiliation, tags, and external profile" do
    profile = {
      source_name: "wikidata",
      external_id: "Q7259",
      source_url: "https://www.wikidata.org/wiki/Q7259",
      fetched_at: Time.current,
      display_name: "Ada Lovelace",
      summary: "English mathematician",
      bio: "Known for early work on computation.",
      tags: [ "Mathematics", "Computing" ],
      affiliations: [ { name: "Analytical Society", category: "community", title: "Member" } ],
      raw_payload: { description: "English mathematician" }
    }

    person = ExternalPeople::Importer.import!(profile: profile)

    assert_equal "Ada Lovelace", person.display_name
    assert_equal [ "Analytical Society" ], person.organizations.pluck(:name)
    assert_equal [ "Computing", "Mathematics" ], person.tags.order(:name).pluck(:name)
    assert_equal "Q7259", person.person_external_profiles.first.external_id
  end

  test "links imported data to an existing person without overwriting filled text" do
    person = Person.create!(
      display_name: "Ada Lovelace",
      summary: "Handwritten summary",
      bio: "Handwritten bio",
      publication_status: "published"
    )

    profile = {
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      display_name: "Ada Lovelace",
      summary: "Imported summary",
      bio: "Imported bio",
      tags: [ "Computation" ],
      affiliations: [],
      raw_payload: {}
    }

    imported_person = ExternalPeople::Importer.import!(profile: profile, target_person: person)

    assert_equal person.id, imported_person.id
    assert_equal "Handwritten summary", imported_person.summary
    assert_equal "Handwritten bio", imported_person.bio
    assert_equal [ "Computation" ], imported_person.tags.order(:name).pluck(:name)
  end
end
