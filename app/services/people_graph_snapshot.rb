require_dependency Rails.root.join("app/services/person_graph_metadata_builder").to_s
class PeopleGraphSnapshot
  CACHE_NAMESPACE = "people-graph/v3".freeze
  CACHE_TTL = 30.minutes

  def initialize(people:, selected_cluster_slug: nil, query: nil, profile_resolver: ExternalPeople::ProfileResolver.new)
    @people = Array(people).compact.uniq { |person| person.id }
    @selected_cluster_slug = selected_cluster_slug.to_s.presence
    @query = query.to_s.strip.presence
    @profile_resolver = profile_resolver
  end

  def fetch
    return build_snapshot unless cacheable?

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      build_snapshot
    end.deep_dup
  end

  private

  def cacheable?
    @query.blank?
  end

  def cache_key
    [
      CACHE_NAMESPACE,
      "all",
      (@selected_cluster_slug || "overview"),
      version_token
    ].join(":")
  end

  def build_snapshot
    graph_profile_metadata_index = graph_profile_metadata_index_for(@people)

    builder = ClusteredPeopleGraphBuilder.new(
      people: @people,
      selected_cluster_slug: @selected_cluster_slug,
      query: @query,
      profile_metadata_by_person_id: graph_profile_metadata_index
    )

    selected_cluster = builder.selected_cluster
    selected_cluster_graph = if selected_cluster.present?
      ImportedPeopleGraphBuilder.new(
        people: selected_cluster.fetch(:graph_people),
        profile_metadata_by_person_id: graph_profile_metadata_index.slice(*selected_cluster.fetch(:graph_people).map(&:id))
      ).payload
    end

    {
      relationship_graph: builder.payload,
      graph_summary: builder.summary,
      selected_cluster: serialize_selected_cluster(selected_cluster),
      selected_cluster_graph: selected_cluster_graph,
      selected_cluster_overlap: builder.selected_cluster_overlap
    }
  end

  def serialize_selected_cluster(selected_cluster)
    return unless selected_cluster

    {
      slug: selected_cluster[:slug],
      label: selected_cluster[:label],
      category: selected_cluster[:category],
      category_label: selected_cluster[:category_label],
      people_count: selected_cluster[:people_count],
      people_ids: selected_cluster.fetch(:people).map(&:id),
      people_preview_ids: selected_cluster.fetch(:people_preview).map(&:id),
      preview_truncated: selected_cluster[:preview_truncated],
      top_organizations: selected_cluster[:top_organizations],
      top_tags: selected_cluster[:top_tags],
      source_breakdown: selected_cluster[:source_breakdown],
      graph_person_ids: selected_cluster.fetch(:graph_people).map(&:id),
      graph_truncated: selected_cluster[:graph_truncated]
    }
  end

  def graph_profile_metadata_index_for(people)
    target_people = Array(people).compact.uniq { |person| person.id }.select do |person|
      next false unless person.person_external_profiles.any?
      next false if PersonGraphMetadataBuilder.new(person).graph_ready?

      person.person_external_profiles.all? do |profile|
        profile.cached_graph_tags.empty? && profile.cached_graph_organizations.empty?
      end
    end

    return {} if target_people.empty?

    @profile_resolver.metadata_index_for(target_people)
  rescue ExternalPeople::Error, StandardError
    {}
  end

  def version_token
    [
      @people.length,
      max_timestamp(@people),
      external_profiles.length,
      max_timestamp(external_profiles),
      person_affiliations.length,
      max_timestamp(person_affiliations),
      person_tags.length,
      max_timestamp(person_tags),
      organizations.length,
      max_timestamp(organizations),
      tags.length,
      max_timestamp(tags)
    ].join("-")
  end

  def external_profiles
    @external_profiles ||= @people.flat_map(&:person_external_profiles)
  end

  def person_affiliations
    @person_affiliations ||= @people.flat_map(&:person_affiliations)
  end

  def person_tags
    @person_tags ||= @people.flat_map(&:person_tags)
  end

  def organizations
    @organizations ||= @people.flat_map(&:organizations).uniq(&:id)
  end

  def tags
    @tags ||= @people.flat_map(&:tags).uniq(&:id)
  end

  def max_timestamp(records)
    Array(records).filter_map { |record| record.updated_at&.to_i }.max.to_i
  end
end
