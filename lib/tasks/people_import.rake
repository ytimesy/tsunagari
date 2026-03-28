namespace :people do
  desc "Import sample people from Wikidata into the local database"
  task :import_wikidata_sample, [:limit] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || 100
    profiles = ExternalPeople::WikidataSampleClient.fetch_people(limit: limit)

    imported_count = 0

    profiles.each do |profile|
      ExternalPeople::Importer.import!(profile: profile)
      imported_count += 1
      puts "Imported #{profile[:display_name]} (#{profile[:external_id]})"
    rescue StandardError => error
      warn "Skipped #{profile[:display_name]}: #{error.message}"
    end

    puts "Imported #{imported_count} / #{profiles.length} people."
  end

  desc "Import sample people from OpenAlex into the local database"
  task :import_openalex_sample, [:limit] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || 100
    profiles = ExternalPeople::OpenAlexClient.fetch_top_people(limit: limit)

    imported_count = 0

    profiles.each do |profile|
      ExternalPeople::Importer.import!(profile: profile)
      imported_count += 1
      puts "Imported #{profile[:display_name]} (#{profile[:external_id]})"
    rescue StandardError => error
      warn "Skipped #{profile[:display_name]}: #{error.message}"
    end

    puts "Imported #{imported_count} / #{profiles.length} people."
  end
end
