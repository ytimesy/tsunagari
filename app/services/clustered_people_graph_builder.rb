require_dependency Rails.root.join("app/services/person_graph_metadata_builder").to_s
require "set"
require "zlib"

class ClusteredPeopleGraphBuilder
  MAX_CLUSTERS = 18
  MAX_CLUSTER_EDGES = 48
  MIN_ORGANIZATION_CLUSTER_SIZE = 2
  MIN_TAG_CLUSTER_SIZE = 3
  MIN_NETWORK_CLUSTER_SIZE = 2
  PEOPLE_PREVIEW_LIMIT = 24
  LARGE_CLUSTER_GRAPH_LIMIT = 60
  OTHER_CLUSTER_SLUG = "other"

  Cluster = Struct.new(:slug, :label, :category, :people, keyword_init: true) do
    def people_count
      people.length
    end
  end

  def initialize(people:, selected_cluster_slug: nil, query: nil, profile_metadata_by_person_id: {})
    @people = Array(people).compact.uniq { |person| person.id }
    @selected_cluster_slug = selected_cluster_slug.to_s.presence
    @query = query.to_s.strip.presence
    @profile_metadata_by_person_id = profile_metadata_by_person_id || {}
  end

  def payload
    {
      centerId: selected_cluster&.dig(:slug),
      nodes: nodes,
      edges: selected_edges,
      layout: "rings",
      labelMode: "all",
      variant: "cluster_overview",
      ariaLabel: "人物群どうしの全体構造を示す全体関係マップ"
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
        graph_people = graph_people_for(cluster)

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
          graph_people: graph_people,
          graph_truncated: people.length > graph_people.length
        }
      end
    end
  end


  def selected_cluster_overlap
    @selected_cluster_overlap ||= build_selected_cluster_overlap
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
        population: cluster.people_count,
        category: cluster.category,
        categoryLabel: category_label(cluster.category),
        selected: selected_cluster&.dig(:slug) == cluster.slug
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

      tone = facts[:tone_counts].max_by { |entry| entry.last }&.first || RelationshipGraphBuilder::SIMILAR_TONE

      {
        source: left.slug,
        target: right.slug,
        sourceLabel: left.label,
        targetLabel: right.label,
        tone: tone,
        toneLabel: tone_label(tone),
        kind: kind,
        kindLabel: RelationshipKindClassifier.label_for(kind),
        kindDescription: RelationshipKindClassifier.description_for(kind),
        reason: cluster_reason(left, right, facts),
        weight: facts[:pair_count],
        pairCount: facts[:pair_count],
        sharedOrganizations: facts[:shared_organizations].sort.first(3),
        sharedTags: facts[:shared_tags].sort.first(3)
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

  def tone_label(tone)
    {
      RelationshipGraphBuilder::SIMILAR_TONE => "近い文脈",
      RelationshipGraphBuilder::DIVERSE_TONE => "越境的な接点"
    }.fetch(tone, tone)
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
    buckets = all_cluster_candidates.each_with_object({}) do |candidate, hash|
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
      cluster_slug = preferred_cluster_slug_for(person) || network_cluster_slug_for(person) || OTHER_CLUSTER_SLUG
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

def all_cluster_candidates
  @all_cluster_candidates ||= candidate_clusters + network_component_clusters
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

  def network_cluster_slug_for(person)
    network_cluster_slug_by_person_id[person.id]
  end

  def network_cluster_slug_by_person_id
    @network_cluster_slug_by_person_id ||= network_component_clusters.each_with_object({}) do |candidate, index|
      candidate.fetch(:person_ids).each { |person_id| index[person_id] = candidate[:slug] }
    end
  end

  def network_component_clusters
    @network_component_clusters ||= begin
      available_slots = [ MAX_CLUSTERS - 1 - candidate_clusters.length, 0 ].max
      if available_slots.zero?
        []
      else
        network_components
          .first(available_slots)
          .map { |component_person_ids| network_cluster_candidate_for(component_person_ids) }
      end
    end
  end

  def network_components
    @network_components ||= begin
      remaining_ids = @people.map(&:id) - directly_clustered_person_ids
      if remaining_ids.empty?
        []
      else
        remaining_set = remaining_ids.to_set
        adjacency = remaining_ids.each_with_object({}) { |person_id, hash| hash[person_id] = Set.new }

        person_relationship_pairs.each do |pair, values|
          left_id, right_id = pair
          next unless remaining_set.include?(left_id) && remaining_set.include?(right_id)
          next if values[:shared_tags].empty? && values[:shared_organizations].empty?

          adjacency[left_id] << right_id
          adjacency[right_id] << left_id
        end

        visited = Set.new

        remaining_ids.filter_map do |person_id|
          next if visited.include?(person_id)

          queue = [ person_id ]
          component = []
          visited << person_id

          until queue.empty?
            current_id = queue.shift
            component << current_id

            adjacency.fetch(current_id).each do |neighbor_id|
              next if visited.include?(neighbor_id)

              visited << neighbor_id
              queue << neighbor_id
            end
          end

          next if component.length < MIN_NETWORK_CLUSTER_SIZE

          component
        end.sort_by do |component|
          [ -component.length, component.map { |person_id| people_by_id.fetch(person_id).display_name }.min.to_s ]
        end
      end
    end
  end

  def network_cluster_candidate_for(component_person_ids)
    organization_counts = Hash.new(0)
    tag_counts = Hash.new(0)

    component_person_ids.each do |person_id|
      metadata = metadata_index.fetch(person_id)
      metadata[:organizations].each { |term| organization_counts[term] += 1 }
      metadata[:tags].each { |term| tag_counts[term] += 1 }
    end

    label, basis = dominant_network_label(organization_counts, tag_counts, component_person_ids.length)

    {
      slug: "net-#{label.parameterize.presence || Zlib.crc32(component_person_ids.join('-')).to_s(36)}-#{component_person_ids.first}",
      label: label,
      category: "network",
      people_count: component_person_ids.length,
      score: component_person_ids.length * 3,
      basis: basis,
      person_ids: component_person_ids
    }
  end

  def dominant_network_label(organization_counts, tag_counts, component_size)
    top_org = organization_counts.max_by { |term, count| [ count, term ] }
    top_tag = tag_counts.max_by { |term, count| [ count, term ] }

    if top_org && (!top_tag || top_org.last >= top_tag.last)
      [ top_org.first, "organization" ]
    elsif top_tag
      [ top_tag.first, "tag" ]
    else
      [ "近縁人物群 #{component_size}", "network" ]
    end
  end

  def directly_clustered_person_ids
    @directly_clustered_person_ids ||= @people.filter_map do |person|
      person.id if preferred_cluster_slug_for(person).present?
    end
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
        category: cluster.category,
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

  def build_selected_cluster_overlap
    cluster = cluster_index[@selected_cluster_slug]
    return unless cluster && venn_eligible_category?(cluster.category)

    candidates = selected_edges.filter_map do |edge|
      neighbor = overlap_neighbor_for(cluster, edge)
      next unless neighbor && venn_eligible_category?(neighbor.category)

      overlap_summary_for(cluster, neighbor, edge)
    end

    return if candidates.empty?

    preferred_candidates = candidates.select { |candidate| candidate[:overlap_count].positive? }
    (preferred_candidates.presence || candidates).max_by do |candidate|
      [ candidate[:overlap_count], candidate[:pair_count], candidate[:neighbor_label] ]
    end
  end

  def overlap_neighbor_for(cluster, edge)
    neighbor_slug = if edge[:source] == cluster.slug
      edge[:target]
    elsif edge[:target] == cluster.slug
      edge[:source]
    end

    return unless neighbor_slug

    cluster_index[neighbor_slug]
  end

  def overlap_summary_for(cluster, neighbor, edge)
    selected_person_ids = membership_person_ids_for(cluster)
    neighbor_person_ids = membership_person_ids_for(neighbor)
    overlap_person_ids = selected_person_ids & neighbor_person_ids
    overlap_names = overlap_person_ids.map { |person_id| people_by_id.fetch(person_id).display_name }.sort

    {
      selected_slug: cluster.slug,
      selected_label: cluster.label,
      selected_category_label: category_label(cluster.category),
      selected_count: selected_person_ids.length,
      neighbor_slug: neighbor.slug,
      neighbor_label: neighbor.label,
      neighbor_category_label: category_label(neighbor.category),
      neighbor_count: neighbor_person_ids.length,
      overlap_count: overlap_person_ids.length,
      union_count: (selected_person_ids | neighbor_person_ids).length,
      left_only_count: selected_person_ids.length - overlap_person_ids.length,
      right_only_count: neighbor_person_ids.length - overlap_person_ids.length,
      pair_count: edge[:pairCount] || edge[:weight] || 0,
      tone_label: edge[:toneLabel],
      kind_label: edge[:kindLabel],
      relation_mode: overlap_relation_mode(selected_person_ids.length, neighbor_person_ids.length, overlap_person_ids.length),
      shared_people_names: overlap_names.first(6),
      shared_people_more_count: [ overlap_names.length - 6, 0 ].max
    }
  end

  def membership_person_ids_for(cluster)
    @membership_person_ids_by_cluster_slug ||= {}
    @membership_person_ids_by_cluster_slug[cluster.slug] ||= case cluster.category
    when "organization"
      metadata_index.filter_map do |person_id, metadata|
        person_id if metadata[:organizations].include?(cluster.label)
      end
    when "tag"
      metadata_index.filter_map do |person_id, metadata|
        person_id if metadata[:tags].include?(cluster.label)
      end
    else
      cluster.people.map(&:id)
    end
  end

  def venn_eligible_category?(category)
    category.in?(%w[organization tag])
  end

  def overlap_relation_mode(selected_count, neighbor_count, overlap_count)
    return "same" if overlap_count == selected_count && overlap_count == neighbor_count
    return "selected_subset" if overlap_count == selected_count
    return "neighbor_subset" if overlap_count == neighbor_count
    return "disjoint" if overlap_count.zero?

    "overlap"
  end

  def graph_people_for(cluster)
    people = cluster.people
    return people.sort_by(&:display_name) if people.length <= LARGE_CLUSTER_GRAPH_LIMIT

    cluster_person_ids = people.map(&:id).to_set
    connection_scores = people.each_with_object(Hash.new(0)) do |person, scores|
      metadata = metadata_index.fetch(person.id)
      scores[person.id] += metadata[:organizations].length * 5
      scores[person.id] += metadata[:tags].length * 3
    end

    person_relationship_pairs.each do |pair, values|
      left_id, right_id = pair
      next unless cluster_person_ids.include?(left_id) && cluster_person_ids.include?(right_id)

      weight = (values[:shared_organizations].length * 5) + (values[:shared_tags].length * 3)
      connection_scores[left_id] += weight
      connection_scores[right_id] += weight
    end

    people
      .sort_by { |person| [ -connection_scores.fetch(person.id, 0), person.display_name ] }
      .first(LARGE_CLUSTER_GRAPH_LIMIT)
      .sort_by(&:display_name)
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
      person.person_external_profiles.any? && !PersonGraphMetadataBuilder.new(person).graph_ready?
    end
  end

  def metadata_index
    @metadata_index ||= @people.each_with_object({}) do |person, index|
      resolved_metadata = @profile_metadata_by_person_id.fetch(person.id, {})
      index[person.id] = PersonGraphMetadataBuilder.build(person, profile_metadata: resolved_metadata)
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
      "network" => "近縁クラスタ",
      "other" => "補助クラスタ"
    }.fetch(category, category)
  end

  def people_by_id
    @people_by_id ||= @people.index_by(&:id)
  end
end
