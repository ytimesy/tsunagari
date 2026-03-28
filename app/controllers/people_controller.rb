require_dependency Rails.root.join("app/services/relationship_graph_builder").to_s
require_dependency Rails.root.join("app/services/imported_people_graph_builder").to_s
require_dependency Rails.root.join("app/services/clustered_people_graph_builder").to_s
require_dependency Rails.root.join("app/services/person_neighborhood_graph_builder").to_s
require_dependency Rails.root.join("app/services/person_case_graph_scope").to_s
require_dependency Rails.root.join("app/services/external_people/profile_resolver").to_s
require_dependency Rails.root.join("app/services/edit_history_recorder").to_s

class PeopleController < ApplicationController
  GLOBAL_GRAPH_LIVE_METADATA_PEOPLE_LIMIT = 60
  GLOBAL_GRAPH_LIVE_METADATA_RESOLUTION_LIMIT = 16

  before_action :set_person, only: %i[show edit update]
  before_action :prepare_form_fields, only: %i[new edit]

  def index
    @query = params[:q].to_s.strip
    @people = base_scope
    @people = apply_search(@people, @query) if @query.present?
    @people = @people.order(:display_name)
  end

  def show
    @cluster_context_slug = params[:cluster].to_s.presence
    @graph_depth = graph_depth_param
    @research_notes = @person.research_notes.order(created_at: :desc)
    @resolved_person_profile = profile_resolver.resolve(@person)
    @relationship_graphs = build_relationship_graphs
    @edit_histories = @person.edit_histories.recent.limit(5)
  end

  def graph
    @query = params[:q].to_s.strip
    @selected_cluster_slug = params[:cluster].to_s.presence
    @people = imported_scope
    @people = apply_search(@people, @query) if @query.present?
    @people = @people.order(:display_name).load
    @graph_profile_metadata_index = graph_profile_metadata_index_for(@people)

    builder = ClusteredPeopleGraphBuilder.new(
      people: @people,
      selected_cluster_slug: @selected_cluster_slug,
      query: @query,
      profile_metadata_by_person_id: @graph_profile_metadata_index
    )
    @relationship_graph = builder.payload
    @graph_summary = builder.summary
    @selected_cluster = builder.selected_cluster
    @selected_cluster_graph = if @selected_cluster.present?
      ImportedPeopleGraphBuilder.new(
        people: @selected_cluster.fetch(:graph_people),
        profile_metadata_by_person_id: @graph_profile_metadata_index.slice(*@selected_cluster.fetch(:graph_people).map(&:id))
      ).payload
    end
    decorate_graph_with_cluster_context!(@selected_cluster_graph, @selected_cluster&.fetch(:graph_people, []), @selected_cluster&.dig(:slug))
    @selected_cluster_graph[:labelMode] = "all" if @selected_cluster_graph.present?
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

    redirect_to @person, notice: "人物を作成しました。"
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

    redirect_to @person, notice: "人物を更新しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :edit, status: :unprocessable_entity
  end

  private

  def set_person
    @person = Person.includes(:person_external_profiles, :tags, person_affiliations: :organization).find_by!(slug: params[:slug])
  end

  def base_scope
    Person.includes(:person_external_profiles, :tags, person_affiliations: :organization)
  end

  def imported_scope
    base_scope.joins(:person_external_profiles).distinct
  end

  def apply_search(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"

    scope.left_joins(:person_external_profiles, :tags, person_affiliations: :organization).where(
      "LOWER(people.display_name) LIKE :query OR LOWER(COALESCE(people.summary, '')) LIKE :query OR LOWER(COALESCE(people.bio, '')) LIKE :query OR LOWER(COALESCE(tags.name, '')) LIKE :query OR LOWER(COALESCE(organizations.name, '')) LIKE :query OR LOWER(COALESCE(person_external_profiles.external_id, '')) LIKE :query OR LOWER(COALESCE(array_to_string(person_external_profiles.graph_tags, ' '), '')) LIKE :query OR LOWER(COALESCE(array_to_string(person_external_profiles.graph_organizations, ' '), '')) LIKE :query",
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
      :tag_list,
      :primary_organization_name,
      :primary_organization_category,
      :primary_organization_website_url,
      :primary_affiliation_title
    )
  end

  def person_attributes
    person_params.slice(:display_name, :summary, :bio, :publication_status, :published_at)
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
      tags: normalized_tag_names(@tag_list),
      affiliation: {
        name: @primary_organization_name.to_s,
        category: @primary_organization_category.to_s,
        website_url: @primary_organization_website_url.to_s,
        title: @primary_affiliation_title.to_s
      }
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
    sections << "タグ" if normalized_tag_names(@tag_list).any?
    sections << "所属" if @primary_organization_name.present?
    sections
  end

  def changed_person_sections(before_snapshot, after_snapshot)
    sections = []
    sections << "人物情報" if before_snapshot[:attributes] != after_snapshot[:attributes]
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

    1.upto(3).each_with_object({}) do |depth, graphs|
      graphs[depth] = relationship_graph_for(depth, candidate_people:, focal_metadata:)
    end
  end

  def relationship_graph_for(depth, candidate_people:, focal_metadata:)
    graph_scope = PersonCaseGraphScope.new(focal_person: @person, depth:).build
    graph_people = graph_scope[:people]
    graph = RelationshipGraphBuilder.new(
      people: graph_people,
      encounter_cases: graph_scope[:encounter_cases],
      focal_person: @person,
      profile_metadata_by_person_id: profile_resolver.metadata_index_for(graph_people)
    ).payload

    if graph[:edges].empty?
      fallback_metadata_index = if @cluster_context_slug.present?
        profile_resolver.metadata_index_for(candidate_people + [ @person ])
      else
        {}
      end

      graph = PersonNeighborhoodGraphBuilder.new(
        focal_person: @person,
        candidates: candidate_people,
        focal_metadata:,
        depth:,
        profile_metadata_by_person_id: fallback_metadata_index
      ).payload
    end

    graph[:labelMode] = "all"
    decorate_graph_with_cluster_context!(graph, graph_people + candidate_people + [ @person ], @cluster_context_slug)
    graph
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

  def graph_profile_metadata_index_for(people)
    target_people = Array(people).compact.uniq { |person| person.id }.select do |person|
      next false unless person.person_external_profiles.any?

      person.tags.empty? &&
        person.organizations.empty? &&
        person.person_external_profiles.all? do |profile|
          profile.cached_graph_tags.empty? && profile.cached_graph_organizations.empty?
        end
    end

    return {} if target_people.empty?
    return {} if @query.blank? && Array(people).length > GLOBAL_GRAPH_LIVE_METADATA_PEOPLE_LIMIT

    profile_resolver.metadata_index_for(target_people.first(GLOBAL_GRAPH_LIVE_METADATA_RESOLUTION_LIMIT))
  rescue ExternalPeople::Error, StandardError
    {}
  end

  def cluster_context
    @cluster_context ||= begin
      people = imported_scope.order(:display_name).load
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
end
