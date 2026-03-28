require_dependency Rails.root.join("app/services/relationship_graph_builder").to_s
require_dependency Rails.root.join("app/services/external_people/profile_resolver").to_s

class PeopleController < ApplicationController
  before_action :set_person, only: %i[show edit update]
  before_action :prepare_form_fields, only: %i[new edit]

  def index
    @query = params[:q].to_s.strip
    @people = base_scope
    @people = apply_search(@people, @query) if @query.present?
    @people = @people.order(:display_name)
  end

  def show
    @related_cases = related_cases_for(@person)
    @research_notes = @person.research_notes.order(created_at: :desc)
    @resolved_person_profile = profile_resolver.resolve(@person)
    graph_people = graph_people_for(@person, @related_cases)
    @relationship_graph = RelationshipGraphBuilder.new(
      people: graph_people,
      encounter_cases: @related_cases,
      focal_person: @person,
      profile_metadata_by_person_id: profile_resolver.metadata_index_for(graph_people)
    ).payload
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
    end

    redirect_to @person, notice: "人物を作成しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    assign_form_values_from_params

    ActiveRecord::Base.transaction do
      @person.update!(person_attributes)
      sync_tags(@person, @tag_list)
      sync_primary_affiliation(@person)
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

  def apply_search(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"

    scope.left_joins(:person_external_profiles, :tags, person_affiliations: :organization).where(
      "LOWER(people.display_name) LIKE :query OR LOWER(COALESCE(people.summary, '')) LIKE :query OR LOWER(COALESCE(people.bio, '')) LIKE :query OR LOWER(COALESCE(tags.name, '')) LIKE :query OR LOWER(COALESCE(organizations.name, '')) LIKE :query OR LOWER(COALESCE(person_external_profiles.external_id, '')) LIKE :query",
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

  def related_cases_for(person)
    person.encounter_cases.includes(
      :case_outcomes,
      case_participants: :person,
      people: [ :tags, { person_affiliations: :organization } ]
    ).order(happened_on: :desc, published_at: :desc).distinct
  end

  def graph_people_for(person, related_cases)
    related_people = related_cases.flat_map(&:people).uniq { |related_person| related_person.id }
    collaborator_counts = Hash.new(0)

    related_cases.each do |encounter_case|
      encounter_case.people.each do |related_person|
        next if related_person.id == person.id

        collaborator_counts[related_person.id] += 1
      end
    end

    collaborators = related_people.reject { |related_person| related_person.id == person.id }
                                 .sort_by { |related_person| [ -collaborator_counts[related_person.id], related_person.display_name ] }
                                 .first(7)

    [ person, *collaborators ]
  end

  def profile_resolver
    @profile_resolver ||= ExternalPeople::ProfileResolver.new
  end
end
