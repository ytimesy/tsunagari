class BoundaryCrossingPeopleImporter
  NON_PERSON_TERMS = %w[
    university institute government division coalition office editorial laboratory
    department center centre initiative federation webinar ministry committee
  ].freeze
  NAME_CONNECTORS = %w[and of the for in on with from to by].freeze

  THEME_PRESETS = {
    "ai_healthcare" => {
      label: "AI × 医療",
      queries: [
        "artificial intelligence medicine",
        "machine learning healthcare",
        "clinical informatics machine learning",
        "biomedical data science"
      ]
    },
    "education_technology" => {
      label: "教育 × テクノロジー",
      queries: [
        "learning sciences technology",
        "educational technology design",
        "computer science education learning analytics",
        "digital pedagogy education"
      ]
    },
    "climate_policy_science" => {
      label: "気候 × 政策 × 科学",
      queries: [
        "climate change policy",
        "sustainability science",
        "environmental governance",
        "energy transition policy"
      ]
    },
    "civic_technology" => {
      label: "市民社会 × テクノロジー",
      queries: [
        "civic technology",
        "public interest technology",
        "digital government",
        "government innovation"
      ]
    }
  }.freeze

  Result = Struct.new(
    :theme_key,
    :theme_label,
    :query_count,
    :candidate_count,
    :imported_count,
    :skipped_count,
    :imported_people,
    :top_tags,
    :top_organizations,
    keyword_init: true
  )

  def initialize(theme: "all", per_query: 8)
    @theme = theme.to_s.presence || "all"
    @per_query = per_query.to_i.positive? ? per_query.to_i : 8
  end

  def import!
    results = selected_presets.map do |theme_key, preset|
      import_preset(theme_key, preset)
    end

    {
      themes: results,
      total_candidates: results.sum(&:candidate_count),
      total_imported: results.sum(&:imported_count),
      total_skipped: results.sum(&:skipped_count)
    }
  end

  def self.theme_keys
    THEME_PRESETS.keys
  end

  private

  def selected_presets
    return THEME_PRESETS.to_a if @theme == "all"

    preset = THEME_PRESETS[@theme]
    raise ArgumentError, "unknown theme: #{@theme}" unless preset

    [ [ @theme, preset ] ]
  end

  def import_preset(theme_key, preset)
    candidates = unique_profiles_for(preset.fetch(:queries))
    imported_people = []
    skipped_count = 0

    candidates.each do |profile|
      person = ExternalPeople::Importer.import!(profile: profile)
      imported_people << person
    rescue StandardError
      skipped_count += 1
    end

    Result.new(
      theme_key: theme_key,
      theme_label: preset.fetch(:label),
      query_count: preset.fetch(:queries).length,
      candidate_count: candidates.length,
      imported_count: imported_people.length,
      skipped_count: skipped_count,
      imported_people: imported_people.uniq(&:id),
      top_tags: top_terms(candidates.flat_map { |profile| Array(profile[:tags]) }),
      top_organizations: top_terms(
        candidates.flat_map do |profile|
          Array(profile[:affiliations]).filter_map do |affiliation|
            affiliation[:name] || affiliation["name"]
          end
        end
      )
    )
  end

  def unique_profiles_for(queries)
    seen = {}

    queries.flat_map do |query|
      ExternalPeople::OpenAlexClient.search_profiles(query, limit: @per_query)
    end.filter_map do |profile|
      next unless person_like_profile?(profile)

      key = [ profile[:source_name], profile[:external_id] ]
      next if seen[key]

      seen[key] = true
      profile
    end
  end

  def top_terms(values)
    Array(values)
      .map { |value| value.to_s.squish }
      .reject(&:blank?)
      .each_with_object(Hash.new(0)) { |term, counts| counts[term] += 1 }
      .sort_by { |term, count| [ -count, term ] }
      .first(8)
  end

  def person_like_profile?(profile)
    name = profile[:display_name].to_s.squish
    return false if name.blank?
    return false if name.length > 70
    return false if name.include?(":")
    return false if name.scan(",").length > 1
    return false if name.match?(/\d/)
    return false if noisy_caps_phrase?(name)
    return false if organization_like_phrase?(name)

    tokens = name.split(/\s+/)
    return false if tokens.length < 2 || tokens.length > 7

    lowercase_connectors = tokens.count { |token| NAME_CONNECTORS.include?(token.downcase) }
    lowercase_words = tokens.count { |token| token.match?(/\A[a-z]/) }
    return false if lowercase_connectors > 2
    return false if lowercase_words > 2

    true
  end

  def noisy_caps_phrase?(name)
    letters = name.gsub(/[^A-Za-z]/, "")
    return false if letters.length < 12

    uppercase_ratio = letters.count("A-Z").to_f / letters.length
    uppercase_ratio >= 0.75
  end

  def organization_like_phrase?(name)
    normalized = " #{name.downcase} "

    NON_PERSON_TERMS.any? do |term|
      normalized.include?(" #{term} ")
    end
  end
end
