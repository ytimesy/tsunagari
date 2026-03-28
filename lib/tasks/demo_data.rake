namespace :demo do
  desc "Generate synthetic encounter cases from existing people for local UI review"
  task :generate_encounter_cases, [:limit] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || DemoData::EncounterCaseGenerator::DEFAULT_LIMIT
    encounter_cases = DemoData::EncounterCaseGenerator.generate!(limit: limit)

    encounter_cases.each do |encounter_case|
      names = encounter_case.people.order(:display_name).pluck(:display_name).join(", ")
      puts "Generated #{encounter_case.title} [#{names}]"
    end

    puts "Generated #{encounter_cases.length} demo encounter cases."
  end
end
