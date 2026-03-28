namespace :people do
  desc "List available boundary-crossing import themes"
  task list_boundary_crossing_themes: :environment do
    BoundaryCrossingPeopleImporter::THEME_PRESETS.each do |theme_key, preset|
      puts "#{theme_key}: #{preset[:label]}"
      preset[:queries].each do |query|
        puts "  - #{query}"
      end
    end
  end

  desc "Import curated boundary-crossing people from OpenAlex"
  task :import_boundary_crossers, [:theme, :per_query] => :environment do |_task, args|
    theme = args[:theme].presence || "all"
    per_query = args[:per_query].presence&.to_i || 8
    summary = BoundaryCrossingPeopleImporter.new(theme:, per_query:).import!

    summary[:themes].each do |result|
      puts "[#{result.theme_label}] imported #{result.imported_count} / #{result.candidate_count} candidates (skipped #{result.skipped_count})"
      puts "  top tags: #{result.top_tags.map { |term, count| "#{term}(#{count})" }.join(', ')}" if result.top_tags.any?
      puts "  top orgs: #{result.top_organizations.map { |term, count| "#{term}(#{count})" }.join(', ')}" if result.top_organizations.any?
    end

    puts "Total imported: #{summary[:total_imported]} / #{summary[:total_candidates]} candidates"
    puts "Total skipped: #{summary[:total_skipped]}"
  end

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

  desc "Warm cached global people graph pages"
  task :warm_graph_cache, [:clusters] => :environment do |_task, args|
    people = Person.includes(:person_external_profiles, :tags, person_affiliations: :organization)
                 .joins(:person_external_profiles)
                 .distinct
                 .order(:display_name)
                 .load

    snapshot = PeopleGraphSnapshot.new(people: people).fetch
    warmed_count = 1
    cluster_limit = args[:clusters].presence&.to_i || 6

    Array(snapshot.dig(:graph_summary, :largest_clusters))
      .reject { |cluster| cluster[:slug] == ClusteredPeopleGraphBuilder::OTHER_CLUSTER_SLUG }
      .first(cluster_limit)
      .each do |cluster|
        PeopleGraphSnapshot.new(
          people: people,
          selected_cluster_slug: cluster[:slug]
        ).fetch
        warmed_count += 1
        puts "Warmed cluster #{cluster[:label]} (#{cluster[:slug]})"
      end

    puts "Warmed #{warmed_count} graph cache entries."
  end
end
