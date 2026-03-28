namespace :people do
  desc "Remove mirrored tags and affiliations from externally-backed people to keep local storage lean"
  task :compact_external_cache, [:clear_text] => :environment do |_task, args|
    clear_text = ActiveModel::Type::Boolean.new.cast(args[:clear_text])
    removed_person_tags = 0
    removed_affiliations = 0
    cleared_people = 0

    Person.joins(:person_external_profiles).distinct.find_each do |person|
      removed_person_tags += person.person_tags.delete_all
      removed_affiliations += person.person_affiliations.delete_all

      next unless clear_text
      next if person.summary.blank? && person.bio.blank?

      person.update_columns(summary: nil, bio: nil)
      cleared_people += 1
    end

    removed_organizations = Organization.left_outer_joins(:person_affiliations).where(person_affiliations: { id: nil }).delete_all
    removed_tags = Tag.left_outer_joins(:person_tags, :case_tags).where(person_tags: { id: nil }, case_tags: { id: nil }).delete_all

    puts "Removed #{removed_person_tags} person tag links."
    puts "Removed #{removed_affiliations} person affiliation links."
    puts "Cleared text fields for #{cleared_people} people." if clear_text
    puts "Removed #{removed_organizations} orphan organizations."
    puts "Removed #{removed_tags} orphan tags."
  end
end
