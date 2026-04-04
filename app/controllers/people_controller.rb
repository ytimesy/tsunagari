require_dependency Rails.root.join("app/services/imported_people_graph_builder").to_s
require_dependency Rails.root.join("app/services/clustered_people_graph_builder").to_s
require_dependency Rails.root.join("app/services/cluster_focus_graph_builder").to_s
require_dependency Rails.root.join("app/services/people_graph_snapshot").to_s
require_dependency Rails.root.join("app/services/person_neighborhood_graph_builder").to_s
require_dependency Rails.root.join("app/services/person_public_estimate_builder").to_s
require_dependency Rails.root.join("app/services/external_people/profile_resolver").to_s
require_dependency Rails.root.join("app/services/edit_history_recorder").to_s

class PeopleController < ApplicationController
  PERSON_GRAPH_FALLBACK_METADATA_RESOLUTION_LIMIT = 120
  PEOPLE_SORTS = %w[name_asc recently_updated recently_published].freeze
  SOURCE_FILTERS = %w[external local].freeze

  before_action :require_editor!, only: %i[new create edit update]
  before_action :set_visible_person, only: :show
  before_action :set_person, only: %i[edit update]
  before_action :prepare_form_fields, only: %i[new edit]

  def index
    prepare_people_index_filters

    @people = base_scope
    @people = apply_search(@people, @query) if @query.present?
    @people = filter_people_by_tag(@people, @selected_tag)
    @people = filter_people_by_affiliation_category(@people, @selected_affiliation_category)
    @people = filter_people_by_publication_status(@people, @selected_publication_status)
    @people = filter_people_by_source(@people, @selected_source_filter)
    @people = apply_people_sort(@people, @selected_sort)

    load_people_index_options
  end

  def youtube_guide
    @query = params[:q].to_s.strip
    @selected_tag = params[:tag].to_s.strip.presence
    @selected_sort = params[:sort].to_s.in?(PEOPLE_SORTS) ? params[:sort].to_s : 'name_asc'
    @people_filters_active = [@query, @selected_tag].any?(&:present?) || @selected_sort != 'name_asc'

    @people = base_scope
    @people = apply_search(@people, @query) if @query.present?
    @people = filter_people_by_tag(@people, @selected_tag)
    @people = apply_people_sort(@people, @selected_sort)
    @people = @people.limit(48)
    load_people_index_options
  end

  def show
    @cluster_context_slug = params[:cluster].to_s.presence
    @graph_depth = graph_depth_param
    @research_notes = can_edit_content? ? @person.research_notes.order(created_at: :desc) : ResearchNote.none
    @resolved_person_profile = profile_resolver.resolve(@person)
    @relationship_graphs = build_relationship_graphs
    @person_navigation_lens = build_person_navigation_lens
    @person_public_estimate = PersonPublicEstimateBuilder.new(
      person: @person,
      resolved_profile: @resolved_person_profile,
      navigation_lens: @person_navigation_lens
    ).build
    @edit_histories = @person.edit_histories.recent.limit(5)
  end

  def graph
    @query = params[:q].to_s.strip
    @selected_cluster_slug = params[:cluster].to_s.presence
    @people = graph_people_scope
    @people = apply_search(@people, @query) if @query.present?
    @people = @people.order(:display_name).load
    snapshot = PeopleGraphSnapshot.new(
      people: @people,
      selected_cluster_slug: @selected_cluster_slug,
      query: @query,
      profile_resolver: profile_resolver
    ).fetch

    @relationship_graph = snapshot.fetch(:relationship_graph)
    @graph_summary = snapshot.fetch(:graph_summary)
    @selected_cluster = hydrate_selected_cluster(snapshot[:selected_cluster])
    @selected_cluster_graph = snapshot[:selected_cluster_graph]
    @selected_cluster_overlap = snapshot[:selected_cluster_overlap]
    @selected_cluster_overlap[:neighbor_href] = graph_people_path(cluster: @selected_cluster_overlap[:neighbor_slug], q: @query.presence) if @selected_cluster_overlap.present?
    focus_graph_builder = ClusterFocusGraphBuilder.new(
      graph: @relationship_graph,
      selected_cluster_slug: @selected_cluster&.dig(:slug),
      query: @query
    )
    @selected_cluster_focus_graph = focus_graph_builder.payload
    @selected_cluster_connections = focus_graph_builder.connections
    decorate_graph_with_cluster_context!(@selected_cluster_graph, @selected_cluster&.fetch(:graph_people, []), @selected_cluster&.dig(:slug))
    @selected_cluster_graph[:labelMode] = "all" if @selected_cluster_graph.present?
    @diagram_showcase = build_diagram_showcase
  end

  def new
    @person = Person.new(publication_status: "draft")
  end

  def create
    @person = Person.new(person_attributes)
    assign_form_values_from_params

    ActiveRecord::Base.transaction do
      @person.save!
      sync_tags(@person, @tag_list)
      sync_primary_affiliation(@person)
      record_person_edit_history(@person, action: "created")
    end

    redirect_to person_destination_path(@person), notice: @person.published? ? "人物を作成しました。" : "人物を下書き保存しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    before_snapshot = person_snapshot(@person)
    assign_form_values_from_params

    ActiveRecord::Base.transaction do
      @person.update!(person_attributes)
      sync_tags(@person, @tag_list)
      sync_primary_affiliation(@person)
      record_person_edit_history(@person, action: "updated", before_snapshot:)
    end

    redirect_to person_destination_path(@person), notice: @person.published? ? "人物を更新しました。" : "人物の公開前データを更新しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :edit, status: :unprocessable_entity
  end

  private

  def set_visible_person
    @person = visible_people_scope.find_by!(slug: params[:slug])
  end

  def set_person
    @person = all_people_scope.find_by!(slug: params[:slug])
  end

  def all_people_scope
    Person.includes(:person_external_profiles, :tags, person_affiliations: :organization)
  end

  def public_people_scope
    all_people_scope.publicly_visible
  end

  def editor_people_scope
    all_people_scope.where.not(publication_status: 'archived')
  end

  def visible_people_scope
    can_edit_content? ? all_people_scope : public_people_scope
  end

  def base_scope
    can_edit_content? ? editor_people_scope : public_people_scope
  end

  def prepare_people_index_filters
    @query = params[:q].to_s.strip
    @selected_tag = params[:tag].to_s.strip.presence
    @selected_affiliation_category = params[:affiliation_category].to_s.strip.presence
    @selected_source_filter = params[:source_filter].to_s.in?(SOURCE_FILTERS) ? params[:source_filter].to_s : nil
    @selected_publication_status = can_edit_content? && params[:publication_status].to_s.in?(Person::PUBLICATION_STATUSES) ? params[:publication_status].to_s : nil
    @selected_sort = params[:sort].to_s.in?(PEOPLE_SORTS) ? params[:sort].to_s : 'name_asc'
    @people_filters_active = [ @query, @selected_tag, @selected_affiliation_category, @selected_source_filter, @selected_publication_status ].any?(&:present?) || @selected_sort != 'name_asc'
  end

  def load_people_index_options
    visible_people_ids = base_scope.select(:id)

    @available_tag_names = Tag.joins(:people)
      .where(people: { id: visible_people_ids })
      .distinct
      .order(:name)
      .pluck(:name)

    @available_affiliation_categories = Organization.joins(:people)
      .where(people: { id: visible_people_ids })
      .where.not(category: [ nil, '' ])
      .distinct
      .order(:category)
      .pluck(:category)
  end


  def filter_people_by_tag(scope, tag_name)
    return scope unless tag_name.present?

    scope.joins(:tags).where(tags: { normalized_name: tag_name.downcase }).distinct
  end

  def filter_people_by_affiliation_category(scope, category)
    return scope unless category.present?

    scope.joins(person_affiliations: :organization).where(organizations: { category: category }).distinct
  end

  def filter_people_by_publication_status(scope, publication_status)
    return scope unless publication_status.present?

    scope.where(publication_status: publication_status)
  end

  def filter_people_by_source(scope, source_filter)
    case source_filter
    when 'external'
      scope.joins(:person_external_profiles).distinct
    when 'local'
      scope.where.missing(:person_external_profiles)
    else
      scope
    end
  end

  def apply_people_sort(scope, sort_key)
    case sort_key
    when 'recently_updated'
      scope.order(updated_at: :desc, display_name: :asc)
    when 'recently_published'
      scope.order(published_at: :desc, updated_at: :desc, display_name: :asc)
    else
      scope.order(display_name: :asc, created_at: :desc)
    end
  end

  def graph_people_scope
    base_scope.distinct
  end

  def apply_search(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"

    scope.left_joins(:person_external_profiles, :tags, person_affiliations: :organization).where(
      "LOWER(people.display_name) LIKE :query OR LOWER(COALESCE(people.summary, '')) LIKE :query OR LOWER(COALESCE(people.bio, '')) LIKE :query OR LOWER(COALESCE(people.recommended_for, '')) LIKE :query OR LOWER(COALESCE(people.meeting_value, '')) LIKE :query OR LOWER(COALESCE(people.fit_modes, '')) LIKE :query OR LOWER(COALESCE(people.introduction_note, '')) LIKE :query OR LOWER(COALESCE(tags.name, '')) LIKE :query OR LOWER(COALESCE(organizations.name, '')) LIKE :query OR LOWER(COALESCE(person_external_profiles.external_id, '')) LIKE :query OR LOWER(COALESCE(array_to_string(person_external_profiles.graph_tags, ' '), '')) LIKE :query OR LOWER(COALESCE(array_to_string(person_external_profiles.graph_organizations, ' '), '')) LIKE :query",
      query: like_query
    ).distinct
  end

  def person_params
    params.require(:person).permit(
      :display_name,
      :summary,
      :bio,
      :publication_status,
      :published_at,
      :recommended_for,
      :meeting_value,
      :fit_modes,
      :introduction_note,
      :last_reviewed_on,
      :tag_list,
      :primary_organization_name,
      :primary_organization_category,
      :primary_organization_website_url,
      :primary_affiliation_title
    )
  end

  def person_attributes
    person_params.slice(:display_name, :summary, :bio, :publication_status, :published_at, :recommended_for, :meeting_value, :fit_modes, :introduction_note, :last_reviewed_on)
  end

  def assign_form_values_from_params
    @tag_list = person_params[:tag_list].to_s
    @primary_organization_name = person_params[:primary_organization_name].to_s
    @primary_organization_category = person_params[:primary_organization_category].to_s
    @primary_organization_website_url = person_params[:primary_organization_website_url].to_s
    @primary_affiliation_title = person_params[:primary_affiliation_title].to_s
  end

  def prepare_form_fields
    return unless defined?(@person) && @person

    @tag_list ||= @person.tags.order(:name).pluck(:name).join(", ")
    affiliation = @person.primary_affiliation
    @primary_organization_name ||= affiliation&.organization&.name.to_s
    @primary_organization_category ||= affiliation&.organization&.category.to_s
    @primary_organization_website_url ||= affiliation&.organization&.website_url.to_s
    @primary_affiliation_title ||= affiliation&.title.to_s
  end

  def sync_tags(person, raw_tag_list)
    tag_names = raw_tag_list.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq
    person.tags = tag_names.map do |name|
      Tag.find_or_initialize_by(normalized_name: name.downcase).tap { |tag| tag.name = name }
    end
  end

  def sync_primary_affiliation(person)
    person.person_affiliations.destroy_all
    return if @primary_organization_name.blank?

    organization = Organization.find_or_initialize_by(slug: Organization.slug_candidate(@primary_organization_name))
    organization.name = @primary_organization_name
    organization.category = @primary_organization_category.presence
    organization.website_url = @primary_organization_website_url.presence
    organization.save!

    person.person_affiliations.create!(
      organization: organization,
      title: @primary_affiliation_title.presence,
      primary_flag: true
    )
  end

  def graph_depth_param
    requested_depth = params[:graph_depth].to_i
    return 1 if requested_depth <= 0

    requested_depth.clamp(1, 3)
  end

  def person_snapshot(person)
    affiliation = person.primary_affiliation

    {
      attributes: {
        display_name: person.display_name.to_s,
        summary: person.summary.to_s,
        bio: person.bio.to_s,
        publication_status: person.publication_status.to_s,
        published_at: person.published_at&.iso8601.to_s
      },
      insight: person_insight_snapshot(person),
      tags: person.tags.order(:name).pluck(:name),
      affiliation: {
        name: affiliation&.organization&.name.to_s,
        category: affiliation&.organization&.category.to_s,
        website_url: affiliation&.organization&.website_url.to_s,
        title: affiliation&.title.to_s
      }
    }
  end

  def requested_person_snapshot
    {
      attributes: {
        display_name: person_attributes[:display_name].to_s,
        summary: person_attributes[:summary].to_s,
        bio: person_attributes[:bio].to_s,
        publication_status: person_attributes[:publication_status].to_s,
        published_at: person_attributes[:published_at].to_s
      },
      insight: requested_person_insight_snapshot,
      tags: normalized_tag_names(@tag_list),
      affiliation: {
        name: @primary_organization_name.to_s,
        category: @primary_organization_category.to_s,
        website_url: @primary_organization_website_url.to_s,
        title: @primary_affiliation_title.to_s
      }
    }
  end

  def person_insight_snapshot(person)
    {
      recommended_for: person.recommended_for.to_s,
      meeting_value: person.meeting_value.to_s,
      fit_modes: person.fit_modes.to_s,
      introduction_note: person.introduction_note.to_s,
      last_reviewed_on: person.last_reviewed_on&.iso8601.to_s
    }
  end

  def requested_person_insight_snapshot
    {
      recommended_for: person_attributes[:recommended_for].to_s,
      meeting_value: person_attributes[:meeting_value].to_s,
      fit_modes: person_attributes[:fit_modes].to_s,
      introduction_note: person_attributes[:introduction_note].to_s,
      last_reviewed_on: person_attributes[:last_reviewed_on].to_s
    }
  end

  def record_person_edit_history(person, action:, before_snapshot: nil)
    changes = if action == "created"
      created_person_sections
    else
      changed_person_sections(before_snapshot, requested_person_snapshot)
    end

    return if action == "updated" && changes.empty?

    EditHistoryRecorder.record!(
      item: person,
      action: action,
      summary: history_summary_for(action, changes, fallback: "人物情報を更新"),
      details: { sections: changes }
    )
  end

  def created_person_sections
    sections = [ "人物情報" ]
    sections << "活用視点" if requested_person_insight_snapshot.values.any?(&:present?)
    sections << "タグ" if normalized_tag_names(@tag_list).any?
    sections << "所属" if @primary_organization_name.present?
    sections
  end

  def changed_person_sections(before_snapshot, after_snapshot)
    sections = []
    sections << "人物情報" if before_snapshot[:attributes] != after_snapshot[:attributes]
    sections << "活用視点" if before_snapshot[:insight] != after_snapshot[:insight]
    sections << "タグ" if before_snapshot[:tags] != after_snapshot[:tags]
    sections << "所属" if before_snapshot[:affiliation] != after_snapshot[:affiliation]
    sections
  end

  def normalized_tag_names(raw_tag_list)
    raw_tag_list.to_s.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq.sort
  end

  def history_summary_for(action, sections, fallback:)
    target = sections.any? ? sections.join("・") : fallback
    action == "created" ? "#{target}を追加" : "#{target}を更新"
  end

  def profile_resolver
    @profile_resolver ||= ExternalPeople::ProfileResolver.new
  end

  def build_relationship_graphs
    candidate_people = graph_candidate_people
    focal_metadata = {
      tags: @resolved_person_profile[:tags],
      organizations: Array(@resolved_person_profile[:affiliations]).map { |affiliation| affiliation[:name] || affiliation["name"] }
    }
    fallback_metadata_index = person_graph_fallback_metadata_index_for(candidate_people + [ @person ])

    1.upto(3).each_with_object({}) do |depth, graphs|
      graph = PersonNeighborhoodGraphBuilder.new(
        focal_person: @person,
        candidates: candidate_people,
        focal_metadata:,
        depth:,
        profile_metadata_by_person_id: fallback_metadata_index
      ).payload

      graph[:labelMode] = "all"
      decorate_graph_with_cluster_context!(graph, candidate_people + [ @person ], @cluster_context_slug)
      graphs[depth] = graph
    end
  end

  def graph_candidate_people
    if @cluster_context_slug.present?
      cluster = cluster_context
      if cluster.present?
        return cluster.fetch(:people).reject { |person| person.id == @person.id }
      end
    end

    base_scope.where.not(id: @person.id).limit(600).to_a
  end

  def build_person_navigation_lens
    primary_graph = @relationship_graphs.fetch(1)
    nodes_by_id = Array(primary_graph[:nodes]).index_by { |node| node[:id] }
    people_by_id = (graph_candidate_people + [ @person ]).compact.uniq { |person| person.id }.index_by(&:id)
    focal_edges = Array(primary_graph[:edges]).select { |edge| edge[:source] == @person.id || edge[:target] == @person.id }
    sorted_edges = focal_edges.sort_by do |edge|
      [ -person_lens_edge_strength(edge), other_node_label_for(edge), edge[:kind].to_s ]
    end
    connections = sorted_edges.map { |edge| build_person_lens_connection(edge, people_by_id, nodes_by_id) }.compact
    primary_people = connections.first(6)
    next_people = build_person_lens_next_people(connections, primary_people)

    {
      primary_people: primary_people,
      relation_reasons: primary_people.select { |connection| person_lens_explains_relationship?(connection) }.first(4),
      next_people: next_people.first(4),
      near_people: primary_people,
      bridge_people: connections.select { |connection| connection[:bridge] }.first(4)
    }
  end

  def build_person_lens_connection(edge, people_by_id, nodes_by_id)
    neighbor_id = edge[:source] == @person.id ? edge[:target] : edge[:source]
    node = nodes_by_id[neighbor_id] || {}
    person = people_by_id[neighbor_id]
    href = node[:href].presence || (person_path(person, cluster: @cluster_context_slug.presence) if person)
    label = node[:label].presence || person&.display_name.to_s
    return if href.blank? || label.blank?

    shared_tags = person_lens_shared_terms_between(@person, person, kind: :tags)
    shared_organizations = person_lens_shared_terms_between(@person, person, kind: :organizations)

    {
      person_id: neighbor_id,
      label: label,
      href: href,
      kind_label: edge[:kindLabel].presence || RelationshipKindClassifier.label_for(edge[:kind]),
      tone_label: edge[:tone] == "diverse" ? "異質な組み合わせ" : "似たもの同士",
      strength_label: person_lens_strength_label(edge),
      reason: edge[:reason].presence || edge[:kindDescription].presence || "近い接点があります。",
      bridge: person_lens_bridge_edge?(edge),
      shared_tags: shared_tags.first(4),
      shared_organizations: shared_organizations.first(3),
      relation_points: build_person_lens_relation_points(
        edge: edge,
        shared_tags: shared_tags,
        shared_organizations: shared_organizations
      ),
      next_step_reason: person_lens_next_step_reason(
        edge,
        shared_tags: shared_tags,
        shared_organizations: shared_organizations
      )
    }
  end

  def build_person_lens_next_people(connections, primary_people)
    primary_ids = primary_people.first(2).map { |connection| connection[:person_id] }
    prioritized = connections.select { |connection| connection[:bridge] } +
      connections.reject { |connection| primary_ids.include?(connection[:person_id]) }
    prioritized = connections if prioritized.empty?

    prioritized.uniq { |connection| connection[:person_id] }
  end

  def person_lens_explains_relationship?(connection)
    connection[:relation_points].any? || connection[:reason].present?
  end

  def build_person_lens_relation_points(edge:, shared_tags:, shared_organizations:)
    points = []

    if edge[:weight].to_i >= 8
      points << "接点の近さ: 強め"
    elsif edge[:weight].to_i.positive?
      points << "接点の近さ: あり"
    end

    if shared_tags.any?
      points << "共通テーマ: #{shared_tags.first(3).join(' / ')}"
    end

    if shared_organizations.any?
      points << "共通所属: #{shared_organizations.first(2).join(' / ')}"
    end

    points
  end

  def person_lens_next_step_reason(edge, shared_tags:, shared_organizations:)
    if person_lens_bridge_edge?(edge)
      "異分野側の接点が見えるため、この人から関係網を広げやすいです。"
    elsif shared_tags.any? && shared_organizations.any?
      "所属とテーマの両方が重なるので、周辺の関係者を読み解きやすいです。"
    elsif edge[:weight].to_i >= 8
      "共通項が多く、この人物を追うと周辺の輪郭が早く見えます。"
    elsif shared_tags.any?
      "同じテーマ軸で次の人物をたどりやすい相手です。"
    elsif shared_organizations.any?
      "同じ所属や組織文脈から関係者を広げやすい相手です。"
    else
      edge[:reason].presence || "次の接点候補として見ておく価値があります。"
    end
  end

  def person_lens_bridge_edge?(edge)
    edge[:tone] == "diverse" || %w[crossing inspiration sharpening].include?(edge[:kind].to_s)
  end

  def person_lens_edge_strength(edge)
    return edge[:weight].to_i if edge[:weight].to_i.positive?

    1
  end

  def person_lens_strength_label(edge)
    case edge[:kind].to_s
    when "same_organization"
      "同じ所属圏"
    when "same_field"
      "同じテーマ圏"
    else
      edge[:weight].to_i.positive? ? "近い接点あり" : "接点あり"
    end
  end

  def other_node_label_for(edge)
    edge[:source] == @person.id ? edge[:targetLabel].to_s : edge[:sourceLabel].to_s
  end

  def person_lens_shared_terms_between(left, right, kind:)
    person_lens_graph_metadata_for(left).fetch(kind) & person_lens_graph_metadata_for(right).fetch(kind)
  end

  def person_lens_graph_metadata_for(person)
    local_metadata = local_graph_metadata_for(person)
    return local_metadata unless person.id == @person.id

    {
      tags: normalize_graph_terms(local_metadata[:tags] + Array(@resolved_person_profile[:tags])),
      organizations: normalize_graph_terms(
        local_metadata[:organizations] + Array(@resolved_person_profile[:affiliations]).map { |affiliation| affiliation[:name] || affiliation["name"] }
      )
    }
  end

  def person_graph_fallback_metadata_index_for(people)
    target_people = Array(people).compact.uniq { |person| person.id }
                         .select { |person| missing_graph_metadata_for?(person) }
                         .sort_by { |person| fallback_metadata_priority_for(person) }
                         .first(PERSON_GRAPH_FALLBACK_METADATA_RESOLUTION_LIMIT)

    return {} if target_people.empty?

    profile_resolver.metadata_index_for(target_people)
  rescue ExternalPeople::Error, StandardError
    {}
  end

  def missing_graph_metadata_for?(person)
    return false unless person.person_external_profiles.any?

    person.tags.empty? &&
      person.organizations.empty? &&
      person.person_external_profiles.all? do |profile|
        profile.cached_graph_tags.empty? && profile.cached_graph_organizations.empty?
      end
  end

  def fallback_metadata_priority_for(person)
    focal_source_name = @person.primary_external_profile&.source_name
    candidate_source_name = person.primary_external_profile&.source_name

    [
      candidate_source_name == focal_source_name ? 0 : 1,
      -person.person_external_profiles.maximum(:fetched_at).to_i,
      person.display_name
    ]
  end

  def cluster_context
    @cluster_context ||= begin
      people = graph_people_scope.order(:display_name).load
      ClusteredPeopleGraphBuilder.new(
        people: people,
        selected_cluster_slug: @cluster_context_slug
      ).selected_cluster
    end
  end

  def decorate_graph_with_cluster_context!(graph, people, cluster_slug)
    return if graph.blank? || cluster_slug.blank?

    people_by_id = Array(people).compact.uniq { |person| person.id }.index_by(&:id)
    graph[:nodes].each do |node|
      person = people_by_id[node[:id]]
      next unless person

      node[:href] = person_path(person, cluster: cluster_slug)
    end
  end

  def build_diagram_showcase
    {
      person_focus: build_person_focus_showcase,
      structure_clusters: @graph_summary[:largest_clusters].first(4)
    }
  end

  def build_person_focus_showcase
    focus = showcase_person_focus
    return unless focus

    person = focus.fetch(:person)
    graph = focus.fetch(:graph)

    {
      person: person,
      graph: graph,
      neighbor_count: [ graph.fetch(:nodes, []).size - 1, 0 ].max,
      tags: local_graph_metadata_for(person)[:tags].first(4),
      organizations: local_graph_metadata_for(person)[:organizations].first(3)
    }
  end


  def showcase_person_focus
    @showcase_person_focus ||= begin
      ranked_showcase_people.each do |person|
        graph = showcase_graph_for(person)
        return { person: person, graph: graph } if graph[:nodes].size > 1 || graph[:edges].any?
      end

      person = ranked_showcase_people.first
      person.present? ? { person: person, graph: showcase_graph_for(person) } : nil
    end
  end

  def showcase_person
    showcase_person_focus&.fetch(:person)
  end

  def ranked_showcase_people
    @ranked_showcase_people ||= begin
      pool = showcase_people_pool

      pool.sort_by do |person|
        metadata = local_graph_metadata_for(person)

        [
          -(metadata[:tags].size + metadata[:organizations].size),
          person.display_name
        ]
      end
    end
  end

  def showcase_graph_for(person)
    @showcase_graphs ||= {}
    @showcase_graphs[person.id] ||= begin
      candidate_people = showcase_people_pool.reject { |candidate| candidate.id == person.id }.first(80)
      graph = PersonNeighborhoodGraphBuilder.new(
        focal_person: person,
        candidates: candidate_people,
        focal_metadata: local_graph_metadata_for(person),
        depth: 1,
        profile_metadata_by_person_id: local_profile_metadata_index_for(candidate_people)
      ).payload

      graph[:labelMode] = "all"
      graph
    end
  end

  def showcase_people_pool
    @showcase_people_pool ||= begin
      pool = @selected_cluster&.fetch(:people, nil).presence || @people.first(120)
      Array(pool).compact.uniq { |person| person.id }
    end
  end


  def local_profile_metadata_index_for(people)
    Array(people).compact.uniq { |person| person.id }.index_with do |person|
      local_graph_metadata_for(person)
    end
  end

  def local_graph_metadata_for(person)
    {
      tags: normalize_graph_terms(
        person.tags.map(&:name) +
        person.person_external_profiles.flat_map(&:cached_graph_tags)
      ),
      organizations: normalize_graph_terms(
        person.organizations.map(&:name) +
        person.person_external_profiles.flat_map(&:cached_graph_organizations)
      )
    }
  end

  def normalize_graph_terms(values)
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

  def hydrate_selected_cluster(snapshot)
    return unless snapshot

    people_by_id = @people.index_by(&:id)

    {
      slug: snapshot[:slug],
      label: snapshot[:label],
      category: snapshot[:category],
      category_label: snapshot[:category_label],
      people_count: snapshot[:people_count],
      people: hydrate_people(snapshot[:people_ids], people_by_id),
      people_preview: hydrate_people(snapshot[:people_preview_ids], people_by_id),
      preview_truncated: snapshot[:preview_truncated],
      top_organizations: snapshot[:top_organizations],
      top_tags: snapshot[:top_tags],
      source_breakdown: snapshot[:source_breakdown],
      graph_people: hydrate_people(snapshot[:graph_person_ids], people_by_id),
      graph_truncated: snapshot[:graph_truncated]
    }
  end

  def hydrate_people(ids, people_by_id)
    Array(ids).filter_map { |person_id| people_by_id[person_id] }
  end
end
