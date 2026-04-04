namespace :tags do
  desc "Sync the 100 representative field tags used by Tsunagari"
  task sync_representative_fields: :environment do
    RepresentativeFieldCatalog.sync_tags!
    puts "Synced #{RepresentativeFieldCatalog.count} representative field tags."
  end
end
