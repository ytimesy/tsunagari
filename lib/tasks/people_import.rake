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

  desc "Refresh lightweight graph cache for imported external profiles"
  task :refresh_graph_cache, [:limit] => :environment do |_task, args|
    scope = PersonExternalProfile.all
    limit = args[:limit].presence&.to_i
    scope = scope.limit(limit) if limit.present?

    updated_count = 0
    failed_count = 0

    scope.find_each do |external_profile|
      provider = ExternalPeople::ProviderRegistry.provider_for(external_profile.source_name)
      remote_profile = provider.fetch_profile(external_profile.external_id)

      external_profile.update!(
        source_url: remote_profile[:source_url].presence || external_profile.source_url,
        fetched_at: remote_profile[:fetched_at] || Time.current,
        graph_tags: ExternalPeople::Importer.graph_tags_from(remote_profile),
        graph_organizations: ExternalPeople::Importer.graph_organizations_from(remote_profile)
      )

      updated_count += 1
      puts "Refreshed #{external_profile.source_name}:#{external_profile.external_id}"
    rescue StandardError => error
      failed_count += 1
      warn "Skipped #{external_profile.source_name}:#{external_profile.external_id} - #{error.message}"
    end

    puts "Updated #{updated_count} external profiles."
    puts "Failed #{failed_count} external profiles."
  end
end
