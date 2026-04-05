require 'test_helper'
require 'tempfile'
require 'json'

class ExternalPeople::SeedProfileImporterTest < ActiveSupport::TestCase
  test 'imports checked-in seed profiles and skips duplicates' do
    Tempfile.create(['diverse_people', '.json']) do |file|
      file.write(JSON.generate([
        {
          source_name: 'wikidata',
          external_id: 'Q7259',
          source_url: 'https://www.wikidata.org/wiki/Q7259',
          fetched_at: Time.current.iso8601,
          display_name: 'Ada Lovelace',
          summary: 'mathematician',
          bio: 'mathematician',
          tags: ['科学', 'scientist'],
          affiliations: [{ name: 'Analytical Society', category: 'organization' }]
        }
      ]))
      file.flush

      first = ExternalPeople::SeedProfileImporter.import!(path: file.path)
      second = ExternalPeople::SeedProfileImporter.import!(path: file.path)

      assert_equal 1, first[:imported_count]
      assert_equal 0, first[:existing_count]
      assert_equal 0, first[:failed].length
      assert_equal 0, second[:imported_count]
      assert_equal 1, second[:existing_count]
      assert_equal 'Ada Lovelace', Person.find_by!(display_name: 'Ada Lovelace').display_name
    end
  end
end
