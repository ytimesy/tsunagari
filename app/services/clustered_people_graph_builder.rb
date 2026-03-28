require "set"
require "zlib"

class ClusteredPeopleGraphBuilder
  MAX_CLUSTERS = 18
  MAX_CLUSTER_EDGES = 48
  MIN_ORGANIZATION_CLUSTER_SIZE = 2
  MIN_TAG_CLUSTER_SIZE = 3
  PEOPLE_PREVIEW_LIMIT = 24
  LARGE_CLUSTER_GRAPH_LIMIT = 60
  OTHER_CLUSTER_SLUG = "other"

  Cluster = Struct.new(:slug, :label, :category, :people, keyword_init: true) do
    def people_count
      people.length
    end
  end

  def initialize(people:, selected_cluster_slug: nil, query: nil)
    @people = Array(people).compact.uniq { |person| person.id }
    @selected_cluster_slug = selected_cluster_slug.to_s.presence
    @query = query.to_s.strip.presence
  end

  def payload
    {
      centerId: selected_cluster&.dig(:slug),
      nodes: nodes,
      edges: selected_edges,
      layout: "rings",
      labelMode: "all"
    }
  end

  def summary
    {
      people_count: @people.count,
      cluster_count: clusters.length,
      connected_cluster_count: connected_cluster_slugs.count,
      isolated_cluster_count: clusters.length - connected_cluster_slugs.count,
      edge_count: selected_edges.count,
      missing_cache_count: missing_cache_count,
      largest_clusters: largest_clusters,
      top_organizations: top_terms_for(:organizations),
      top_tags: top_terms_for(:tags),
      source_breakdown: source_breakdown
    }
  end

  def selected_cluster
    @selected_cluster ||= begin
      cluster = cluster_index[@selected_cluster_slug]
      if cluster
        people = cluster.people.sort_by(&:display_name)

        {
          slug: cluster.slug,
          label: cluster.label,
          category: cluster.category,
          category_label: category_label(cluster.category),
          people_count: people.length,
          people: people,
          people_preview: people.first(PEOPLE_PREVIEW_LIMIT),
          preview_truncated: people.length > PEOPLE_PREVIEW_LIMIT,
          top_organizations: top_terms_for_cluster(cluster, :organizations),
          top_tags: top_terms_for_cluster(cluster, :tags),
          source_breakdown: source_breakdown_for_cluster(cluster),
          graph_people: people.first(LARGE_CLUSTER_GRAPH_LIMIT),
          graph_allowed: people.length <= LARGE_CLUSTER_GRAPH_LIMIT
        }
      end
    end
  end

  private

  def nodes
    clusters.sort_by { |cluster| [ -cluster.people_count, cluster.label ] }.map do |cluster|
      {
        id: cluster.slug,
        label: cluster.label,
        href: cluster_href(cluster.slug),
        role: node_role_for(cluster),
        degree: degree_by_cluster_slug.fetch(cluster.slug, 0),
        population: cluster.people_count
      }
    end
  end

  def node_role_for(cluster)
    return "focus" if selected_cluster&.dig(:slug) == cluster.slug
    return "isolated" unless connected_cluster_slugs.include?(cluster.slug)

    "cluster"
  end

  def cluster_href(cluster_slug)
    params = {}
    params[:cluster] = cluster_slug
    params[:q] = @query if @query.present?
    Rails.application.routes.url_helpers.graph_people_path(**params)
  end

  def selected_edges
    @selected_edges ||= cluster_pair_candidates.sort_by do |candidate|
      [ -candidate[:weight], candidate[:sourceLabel], candidate[:targetLabel] ]
    end.first(MAX_CLUSTER_EDGES)
  end

  def cluster_pair_candidates
    cluster_pair_accumulator.map do |pair, facts|
      left = cluster_index.fetch(pair.first)
      right = cluster_index.fetch(pair.last)
      kind = facts[:kind_counts].max_by { |entry| [ entry.last, entry.first ] }&.first || "crossing"

      {
        source: left.slug,
        target: right.slug,
        sourceLabel: left.label,
        targetLabel: right.label,
        tone: facts[:tone_counts].max_by { |entry| entry.last }&.first || RelationshipGraphBuilder::SIMILAR_TONE,
        kind: kind,
        kindLabel: RelationshipKindClassifier.label_for(kind),
        kindDescription: RelationshipKindClassifier.description_for(kind),
        reason: cluster_reason(left, right, facts),
        weight: facts[:pair_count]
      }
    end
  end

  def cluster_reason(left, right, facts)
    reasons = []
    reasons << "#{left.label} と #{right.label} の間に #{facts[:pair_count]} 件の人物接点"
    reasons << "代表所属: #{facts[:shared_organizations].sort.first(2).join(', ')}" if facts[:shared_organizations].any?
    reasons << "代表タグ: #{facts[:shared_tags].sort.first(2).join(', ')}" if facts[:shared_tags].any?
    reasons.join(" / ")
  end

  def cluster_pair_accumulator
    @cluster_pair_accumulator ||= begin
      accumulator = Hash.new do |hash, key|
        hash[key] = {
          pair_count: 0,
          kind_counts: Hash.new(0),
          tone_counts: Hash.new(0),
          shared_tags: Set.new,
          shared_organizations: Set.new
        }
      end

      person_relationship_pairs.each do |pair, values|
        left_cluster = cluster_slug_by_person_id[pair.first]
        right_cluster = cluster_slug_by_person_id[pair.last]
        next if left_cluster.blank? || right_cluster.blank?
        next if left_cluster == right_cluster

        edge_key = [ left_cluster, right_cluster ].sort
        facts = accumulator[edge_key]
        classification = RelationshipKindClassifier.classify(
          shared_tags: values[:shared_tags],
          shared_organizations: values[:shared_organizations]
        )

        facts[:pair_count] += 1
        facts[:kind_counts][classification[:kind]] += 1
        facts[:tone_counts][classification[:tone]] += 1
        values[:shared_tags].each { |term| facts[:shared_tags] << term }
        values[:shared_organizations].each { |term| facts[:shared_organizations] << term }
      end

      accumulator
    end
  end

  def person_relationship_pairs
    @person_relationship_pairs ||= begin
      accumulator = Hash.new do |hash, key|
        hash[key] = { shared_tags: [], shared_organizations: [] }
      end

      add_term_pairs!(accumulator, :shared_tags, metadata_key: :tags)
      add_term_pairs!(accumulator, :shared_organizations, metadata_key: :organizations)

      accumulator
    end
  end

  def add_term_pairs!(accumulator, bucket_key, metadata_key:)
    grouped_terms(metadata_key).each do |term, person_ids|
      next if person_ids.size < 2

      person_ids.combination(2) do |left_id, right_id|
        accumulator[[ left_id, right_id ].sort][bucket_key] << term
      end
    end
  end

  def grouped_terms(metadata_key)
    metadata_index.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(person_id, metadata), groups|
      metadata.fetch(metadata_key).each do |term|
        groups[term] << person_id
      end
    end.transform_values(&:uniq)
  end

  def clusters
    @clusters ||= begin
      buckets = candidate_clusters.each_with_object({}) do |candidate, hash|
        hash[candidate[:slug]] = Cluster.new(
          slug: candidate[:slug],
          label: candidate[:label],
          category: candidate[:category],
          people: []
        )
      end

      buckets[OTHER_CLUSTER_SLUG] = Cluster.new(
        slug: OTHER_CLUSTER_SLUG,
        label: "その他",
        category: "other",
        people: []
      )

      @people.each do |person|
        cluster_slug = preferred_cluster_slug_for(person) || OTHER_CLUSTER_SLUG
        buckets.fetch(cluster_slug).people << person
      end

      buckets.values.reject { |cluster| cluster.people.empty? }
    end
  end

  def cluster_index
    @cluster_index ||= clusters.index_by(&:slug)
  end

  def candidate_clusters
    @candidate_clusters ||= begin
      organization_candidates = grouped_terms(:organizations).filter_map do |term, person_ids|
        next if person_ids.size < MIN_ORGANIZATION_CLUSTER_SIZE

        cluster_candidate_for(term:, category: "organization", people_count: person_ids.size)
      end

      tag_candidates = grouped_terms(:tags).filter_map do |term, person_ids|
        next if person_ids.size < MIN_TAG_CLUSTER_SIZE

        cluster_candidate_for(term:, category: "tag", people_count: person_ids.size)
      end

      (organization_candidates + tag_candidates)
        .sort_by { |candidate| [ -candidate[:score], -candidate[:people_count], candidate[:label] ] }
        .first(MAX_CLUSTERS - 1)
    end
  end

  def cluster_candidate_for(term:, category:, people_count:)
    prefix = category == "organization" ? "org" : "tag"
    {
      slug: "#{prefix}-#{term.parameterize.presence || Zlib.crc32(term).to_s(36)}",
      label: term,
      category: category,
      people_count: people_count,
      score: people_count * (category == "organization" ? 10 : 4)
    }
  end

  def preferred_cluster_slug_for(person)
    matched_candidates = candidate_clusters.select do |candidate|
      metadata_index.fetch(person.id).fetch(candidate_term_bucket(candidate)).include?(candidate[:label])
    end

    matched_candidates.max_by { |candidate| [ candidate[:score], candidate[:people_count], candidate[:label] ] }&.dig(:slug)
  end

  def candidate_term_bucket(candidate)
    candidate[:category] == "organization" ? :organizations : :tags
  end

  def cluster_slug_by_person_id
    @cluster_slug_by_person_id ||= clusters.each_with_object({}) do |cluster, index|
      cluster.people.each { |person| index[person.id] = cluster.slug }
    end
  end

  def connected_cluster_slugs
    @connected_cluster_slugs ||= degree_by_cluster_slug.keys
  end

  def degree_by_cluster_slug
    @degree_by_cluster_slug ||= selected_edges.each_with_object(Hash.new(0)) do |edge, counts|
      counts[edge[:source]] += 1
      counts[edge[:target]] += 1
    end
  end

  def largest_clusters
    clusters.sort_by { |cluster| [ -cluster.people_count, cluster.label ] }.first(8).map do |cluster|
      {
        slug: cluster.slug,
        label: cluster.label,
        category_label: category_label(cluster.category),
        people_count: cluster.people_count
      }
    end
  end

  def top_terms_for_cluster(cluster, key)
    cluster.people.each_with_object(Hash.new(0)) do |person, counts|
      metadata_index.fetch(person.id).fetch(key).each { |term| counts[term] += 1 }
    end.sort_by { |term, count| [ -count, term ] }.first(6)
  end

  def source_breakdown_for_cluster(cluster)
    cluster.people.each_with_object(Hash.new(0)) do |person, counts|
      metadata_index.fetch(person.id).fetch(:source_names).each { |source_name| counts[source_name] += 1 }
    end.sort_by { |source_name, count| [ -count, source_name ] }
  end

  def top_terms_for(key)
    metadata_index.values.each_with_object(Hash.new(0)) do |metadata, counts|
      metadata.fetch(key).each { |term| counts[term] += 1 }
    end.sort_by { |term, count| [ -count, term ] }.first(8)
  end

  def source_breakdown
    metadata_index.values.flat_map { |metadata| metadata[:source_names] }
                 .each_with_object(Hash.new(0)) { |source_name, counts| counts[source_name] += 1 }
                 .sort_by { |source_name, count| [ -count, source_name ] }
  end

  def missing_cache_count
    @people.count do |person|
      person.tags.empty? &&
        person.organizations.empty? &&
        person.person_external_profiles.all? do |profile|
          profile.cached_graph_tags.empty? && profile.cached_graph_organizations.empty?
        end
    end
  end

  def metadata_index
    @metadata_index ||= @people.each_with_object({}) do |person, index|
      index[person.id] = {
        tags: normalized_terms(person.tags.map(&:name) + person.person_external_profiles.flat_map(&:cached_graph_tags)),
        organizations: normalized_terms(person.organizations.map(&:name) + person.person_external_profiles.flat_map(&:cached_graph_organizations)),
        source_names: person.person_external_profiles.map(&:source_name).compact.uniq
      }
    end
  end

  def normalized_terms(values)
    seen = {}

    Array(values).filter_map do |value|
      term = value.to_s.squish
      next if term.blank?

      key = term.downcase
      next if seen[key]

      seen[key] = true
      term
    end
  end

  def category_label(category)
    {
      "organization" => "所属クラスタ",
      "tag" => "分野クラスタ",
      "other" => "補助クラスタ"
    }.fetch(category, category)
  end
end
