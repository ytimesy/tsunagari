require "test_helper"

class PeopleGraphSnapshotTest < ActiveSupport::TestCase
  test "caches global graph snapshots for blank queries" do
    ada = create_imported_person("Ada Lovelace", "A1")
    grace = create_imported_person("Grace Hopper", "A2")
    people = imported_people_scope

    call_count = 0
    resolver = Object.new
    resolver.define_singleton_method(:metadata_index_for) do |target_people|
      call_count += 1

      Array(target_people).each_with_object({}) do |person, index|
        organization = person.id == ada.id ? "Analytical Society" : "Computing Guild"

        index[person.id] = {
          tags: [ "Computing" ],
          organizations: [ organization ]
        }
      end
    end

    store = ActiveSupport::Cache::MemoryStore.new

    with_stubbed_method(Rails, :cache, store) do
      first = PeopleGraphSnapshot.new(people: people, profile_resolver: resolver).fetch
      second = PeopleGraphSnapshot.new(people: people, profile_resolver: resolver).fetch

      assert_equal 1, call_count
      assert_equal first[:relationship_graph], second[:relationship_graph]
      assert_equal first[:graph_summary], second[:graph_summary]
    end
  end

  test "does not cache filtered graph snapshots" do
    create_imported_person("Ada Lovelace", "A1")
    people = imported_people_scope

    call_count = 0
    resolver = Object.new
    resolver.define_singleton_method(:metadata_index_for) do |target_people|
      call_count += 1

      Array(target_people).each_with_object({}) do |person, index|
        index[person.id] = {
          tags: [ "Computing" ],
          organizations: [ "Analytical Society" ]
        }
      end
    end

    store = ActiveSupport::Cache::MemoryStore.new

    with_stubbed_method(Rails, :cache, store) do
      PeopleGraphSnapshot.new(people: people, query: "ada", profile_resolver: resolver).fetch
      PeopleGraphSnapshot.new(people: people, query: "ada", profile_resolver: resolver).fetch
    end

    assert_equal 2, call_count
  end

  private

  def create_imported_person(display_name, external_id)
    person = Person.create!(display_name:, publication_status: "published")
    person.person_external_profiles.create!(
      source_name: "openalex",
      external_id:,
      source_url: "https://openalex.org/#{external_id}",
      fetched_at: Time.current
    )
    person
  end

  def imported_people_scope
    Person.includes(:person_external_profiles, :tags, person_affiliations: :organization)
          .joins(:person_external_profiles)
          .distinct
          .order(:display_name)
          .load
  end
end
