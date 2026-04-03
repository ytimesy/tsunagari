require_dependency Rails.root.join("app/services/relationship_graph_builder").to_s
require_dependency Rails.root.join("app/services/external_people/profile_resolver").to_s
require_dependency Rails.root.join("app/services/edit_history_recorder").to_s

class EncounterCasesController < ApplicationController
  CASE_SORTS = %w[newest oldest recently_updated].freeze

  before_action :require_editor!, only: %i[new create edit update]
  before_action :set_visible_encounter_case, only: :show
  before_action :set_encounter_case, only: %i[edit update]
  before_action :prepare_form_fields, only: %i[new edit]

  def index
    prepare_case_index_filters

    @encounter_cases = base_scope
    @encounter_cases = apply_search(@encounter_cases, @query) if @query.present?
    @encounter_cases = filter_cases_by_tag(@encounter_cases, @selected_tag)
    @encounter_cases = filter_cases_by_outcome_direction(@encounter_cases, @selected_outcome_direction)
    @encounter_cases = filter_cases_by_evidence_level(@encounter_cases, @selected_evidence_level)
    @encounter_cases = filter_cases_by_publication_status(@encounter_cases, @selected_publication_status)
    @encounter_cases = filter_cases_by_date_range(@encounter_cases, @parsed_date_from, @parsed_date_to)
    @encounter_cases = apply_case_sort(@encounter_cases, @selected_sort)

    load_case_index_options
  end

  def show
    @research_notes = can_edit_content? ? @encounter_case.research_notes.order(created_at: :desc) : ResearchNote.none
    @edit_histories = @encounter_case.edit_histories.recent.limit(5)
    case_people = @encounter_case.people.to_a
    @relationship_graph = RelationshipGraphBuilder.new(
      people: case_people,
      encounter_cases: [ @encounter_case ],
      profile_metadata_by_person_id: profile_resolver.metadata_index_for(case_people)
    ).payload
    case_people_by_id = case_people.index_by(&:id)
    @relationship_graph[:nodes].each do |node|
      person = case_people_by_id[node[:id]]
      node[:href] = person_destination_path(person) if person&.visible_to?(current_user)
      node.delete(:href) unless person&.visible_to?(current_user)
    end
  end

  def new
    @encounter_case = EncounterCase.new(publication_status: "draft")
  end

  def create
    @encounter_case = EncounterCase.new(encounter_case_attributes)
    assign_form_values_from_params
    validate_publish_requirements!

    ActiveRecord::Base.transaction do
      @encounter_case.save!
      sync_tags(@encounter_case, @tag_list)
      sync_participants(@encounter_case)
      sync_outcomes(@encounter_case)
      sync_case_insights(@encounter_case)
      sync_sources(@encounter_case)
      record_encounter_case_edit_history(@encounter_case, action: "created")
    end

    redirect_to encounter_case_destination_path(@encounter_case), notice: @encounter_case.published? ? "出会い事例を作成しました。" : "出会い事例を下書き保存しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    before_snapshot = encounter_case_snapshot(@encounter_case)
    assign_form_values_from_params
    validate_publish_requirements!

    ActiveRecord::Base.transaction do
      @encounter_case.update!(encounter_case_attributes)
      sync_tags(@encounter_case, @tag_list)
      sync_participants(@encounter_case)
      sync_outcomes(@encounter_case)
      sync_case_insights(@encounter_case)
      sync_sources(@encounter_case)
      record_encounter_case_edit_history(@encounter_case, action: "updated", before_snapshot:)
    end

    redirect_to encounter_case_destination_path(@encounter_case), notice: @encounter_case.published? ? "出会い事例を更新しました。" : "出会い事例の公開前データを更新しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :edit, status: :unprocessable_entity
  end

  private

  def set_visible_encounter_case
    @encounter_case = visible_case_scope.find_by!(slug: params[:slug])
  end

  def set_encounter_case
    @encounter_case = all_case_scope.find_by!(slug: params[:slug])
  end

  def all_case_scope
    EncounterCase.includes(
      :case_outcomes,
      :case_insights,
      :sources,
      :tags,
      case_participants: :person,
      people: [ :tags, { person_affiliations: :organization } ]
    )
  end

  def public_case_scope
    all_case_scope.publicly_visible
  end

  def editor_case_scope
    all_case_scope.where.not(publication_status: 'archived')
  end

  def visible_case_scope
    can_edit_content? ? all_case_scope : public_case_scope
  end

  def base_scope
    can_edit_content? ? editor_case_scope : public_case_scope
  end

  def prepare_case_index_filters
    @query = params[:q].to_s.strip
    @selected_tag = params[:tag].to_s.strip.presence
    @selected_outcome_direction = params[:outcome_direction].to_s.in?(CaseOutcome::OUTCOME_DIRECTIONS) ? params[:outcome_direction].to_s : nil
    @selected_evidence_level = params[:evidence_level].to_s.in?(CaseOutcome::EVIDENCE_LEVELS) ? params[:evidence_level].to_s : nil
    @selected_publication_status = can_edit_content? && params[:publication_status].to_s.in?(EncounterCase::PUBLICATION_STATUSES) ? params[:publication_status].to_s : nil
    @date_from = params[:date_from].to_s
    @date_to = params[:date_to].to_s
    @parsed_date_from = parse_filter_date(@date_from)
    @parsed_date_to = parse_filter_date(@date_to)
    @selected_sort = params[:sort].to_s.in?(CASE_SORTS) ? params[:sort].to_s : 'newest'
    @case_filters_active = [ @query, @selected_tag, @selected_outcome_direction, @selected_evidence_level, @selected_publication_status, @date_from, @date_to ].any?(&:present?) || @selected_sort != 'newest'
  end

  def load_case_index_options
    visible_case_ids = base_scope.select(:id)

    @available_tag_names = Tag.joins(:encounter_cases)
      .where(encounter_cases: { id: visible_case_ids })
      .distinct
      .order(:name)
      .pluck(:name)
  end

  def filter_cases_by_tag(scope, tag_name)
    return scope unless tag_name.present?

    scope.joins(:tags).where(tags: { normalized_name: tag_name.downcase }).distinct
  end

  def filter_cases_by_outcome_direction(scope, outcome_direction)
    return scope unless outcome_direction.present?

    scope.joins(:case_outcomes).where(case_outcomes: { outcome_direction: outcome_direction }).distinct
  end

  def filter_cases_by_evidence_level(scope, evidence_level)
    return scope unless evidence_level.present?

    scope.joins(:case_outcomes).where(case_outcomes: { evidence_level: evidence_level }).distinct
  end

  def filter_cases_by_publication_status(scope, publication_status)
    return scope unless publication_status.present?

    scope.where(publication_status: publication_status)
  end

  def filter_cases_by_date_range(scope, date_from, date_to)
    scoped = scope
    scoped = scoped.where('encounter_cases.happened_on >= ?', date_from) if date_from.present?
    scoped = scoped.where('encounter_cases.happened_on <= ?', date_to) if date_to.present?
    scoped
  end

  def apply_case_sort(scope, sort_key)
    case sort_key
    when 'oldest'
      scope.order(happened_on: :asc, created_at: :asc)
    when 'recently_updated'
      scope.order(updated_at: :desc, happened_on: :desc, created_at: :desc)
    else
      scope.order(happened_on: :desc, published_at: :desc, created_at: :desc)
    end
  end

  def parse_filter_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def apply_search(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"

    scope.left_joins(:tags, :people).where(
      "LOWER(encounter_cases.title) LIKE :query OR LOWER(COALESCE(encounter_cases.summary, '')) LIKE :query OR LOWER(COALESCE(encounter_cases.background, '')) LIKE :query OR LOWER(COALESCE(tags.name, '')) LIKE :query OR LOWER(COALESCE(people.display_name, '')) LIKE :query",
      query: like_query
    ).distinct
  end

  def encounter_case_params
    params.require(:encounter_case).permit(
      :title,
      :summary,
      :background,
      :happened_on,
      :place,
      :publication_status,
      :published_at,
      :tag_list,
      :participant_names,
      :participant_role,
      :outcome_category,
      :outcome_direction,
      :outcome_description,
      :impact_scope,
      :evidence_level,
      :insight_type,
      :insight_description,
      :application_note,
      :source_title,
      :source_url,
      :source_type,
      :source_published_on
    )
  end

  def encounter_case_attributes
    encounter_case_params.slice(:title, :summary, :background, :happened_on, :place, :publication_status, :published_at)
  end

  def assign_form_values_from_params
    @tag_list = encounter_case_params[:tag_list].to_s
    @participant_names = encounter_case_params[:participant_names].to_s
    @participant_role = encounter_case_params[:participant_role].presence || "participant"
    @outcome_category = encounter_case_params[:outcome_category].to_s
    @outcome_direction = encounter_case_params[:outcome_direction].presence || "positive"
    @outcome_description = encounter_case_params[:outcome_description].to_s
    @impact_scope = encounter_case_params[:impact_scope].to_s
    @evidence_level = encounter_case_params[:evidence_level].to_s
    @insight_type = encounter_case_params[:insight_type].presence || "lesson"
    @insight_description = encounter_case_params[:insight_description].to_s
    @application_note = encounter_case_params[:application_note].to_s
    @source_title = encounter_case_params[:source_title].to_s
    @source_url = encounter_case_params[:source_url].to_s
    @source_type = encounter_case_params[:source_type].to_s
    @source_published_on = encounter_case_params[:source_published_on].to_s
  end

  def prepare_form_fields
    return unless defined?(@encounter_case) && @encounter_case

    @tag_list ||= @encounter_case.tags.order(:name).pluck(:name).join(", ")
    @participant_names ||= @encounter_case.people.order(:display_name).pluck(:display_name).join(", ")
    @participant_role ||= @encounter_case.case_participants.first&.participation_role.to_s.presence || "participant"
    primary_outcome = @encounter_case.case_outcomes.first
    @outcome_category ||= primary_outcome&.category.to_s
    @outcome_direction ||= primary_outcome&.outcome_direction.to_s.presence || "positive"
    @outcome_description ||= primary_outcome&.description.to_s
    @impact_scope ||= primary_outcome&.impact_scope.to_s
    @evidence_level ||= primary_outcome&.evidence_level.to_s
    primary_insight = @encounter_case.case_insights.first
    @insight_type ||= primary_insight&.insight_type.to_s.presence || "lesson"
    @insight_description ||= primary_insight&.description.to_s
    @application_note ||= primary_insight&.application_note.to_s
    primary_source = @encounter_case.sources.first
    @source_title ||= primary_source&.title.to_s
    @source_url ||= primary_source&.url.to_s
    @source_type ||= primary_source&.source_type.to_s
    @source_published_on ||= primary_source&.published_on&.to_s.to_s
  end

  def validate_publish_requirements!
    return unless encounter_case_attributes[:publication_status] == "published"

    if @participant_names.blank?
      @encounter_case.errors.add(:base, "公開するには参加人物が必要です。")
    end
    if @outcome_description.blank?
      @encounter_case.errors.add(:base, "公開するには結果の記述が必要です。")
    end
    if @source_url.blank?
      @encounter_case.errors.add(:base, "公開するには出典が必要です。")
    end

    raise ActiveRecord::RecordInvalid, @encounter_case if @encounter_case.errors.any?
  end

  def sync_tags(encounter_case, raw_tag_list)
    tag_names = raw_tag_list.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq
    encounter_case.tags = tag_names.map do |name|
      Tag.find_or_initialize_by(normalized_name: name.downcase).tap { |tag| tag.name = name }
    end
  end

  def sync_participants(encounter_case)
    names = @participant_names.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq
    encounter_case.case_participants.destroy_all

    names.each do |name|
      person = Person.find_or_initialize_by(slug: Person.slug_candidate(name))
      person.display_name = name
      person.publication_status ||= "draft"
      person.save!

      encounter_case.case_participants.create!(
        person: person,
        participation_role: @participant_role.presence || "participant"
      )
    end
  end

  def sync_outcomes(encounter_case)
    encounter_case.case_outcomes.destroy_all
    return if @outcome_description.blank?

    encounter_case.case_outcomes.create!(
      category: @outcome_category.presence || "general",
      outcome_direction: @outcome_direction.presence || "positive",
      description: @outcome_description,
      impact_scope: @impact_scope.presence,
      evidence_level: @evidence_level.presence || "reported"
    )
  end

  def sync_case_insights(encounter_case)
    encounter_case.case_insights.destroy_all
    return if @insight_description.blank?

    encounter_case.case_insights.create!(
      insight_type: @insight_type.presence || "lesson",
      description: @insight_description,
      application_note: @application_note.presence
    )
  end

  def sync_sources(encounter_case)
    encounter_case.case_sources.destroy_all
    return if @source_url.blank?

    source = Source.find_or_initialize_by(url: @source_url)
    source.title = @source_title.presence || @source_url
    source.source_type = @source_type.presence
    source.published_on = @source_published_on.presence
    source.save!

    encounter_case.case_sources.create!(
      source: source,
      citation_note: @source_title.presence
    )
  end

  def profile_resolver
    @profile_resolver ||= ExternalPeople::ProfileResolver.new
  end

  def encounter_case_snapshot(encounter_case)
    primary_outcome = encounter_case.case_outcomes.first
    primary_insight = encounter_case.case_insights.first
    primary_source = encounter_case.sources.first

    {
      attributes: {
        title: encounter_case.title.to_s,
        summary: encounter_case.summary.to_s,
        background: encounter_case.background.to_s,
        happened_on: encounter_case.happened_on&.iso8601.to_s,
        place: encounter_case.place.to_s,
        publication_status: encounter_case.publication_status.to_s,
        published_at: encounter_case.published_at&.iso8601.to_s
      },
      tags: encounter_case.tags.order(:name).pluck(:name),
      participants: encounter_case.case_participants.order(:person_id).map { |participant| [ participant.person.display_name, participant.participation_role.to_s ] },
      outcome: {
        category: primary_outcome&.category.to_s,
        direction: primary_outcome&.outcome_direction.to_s,
        description: primary_outcome&.description.to_s,
        impact_scope: primary_outcome&.impact_scope.to_s,
        evidence_level: primary_outcome&.evidence_level.to_s
      },
      insight: {
        insight_type: primary_insight&.insight_type.to_s,
        description: primary_insight&.description.to_s,
        application_note: primary_insight&.application_note.to_s
      },
      source: {
        title: primary_source&.title.to_s,
        url: primary_source&.url.to_s,
        source_type: primary_source&.source_type.to_s,
        published_on: primary_source&.published_on&.iso8601.to_s
      }
    }
  end

  def requested_encounter_case_snapshot
    participants = @participant_names.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq.sort.map do |name|
      [ name, @participant_role.to_s ]
    end

    {
      attributes: {
        title: encounter_case_attributes[:title].to_s,
        summary: encounter_case_attributes[:summary].to_s,
        background: encounter_case_attributes[:background].to_s,
        happened_on: encounter_case_attributes[:happened_on].to_s,
        place: encounter_case_attributes[:place].to_s,
        publication_status: encounter_case_attributes[:publication_status].to_s,
        published_at: encounter_case_attributes[:published_at].to_s
      },
      tags: normalized_case_tag_names(@tag_list),
      participants: participants,
      outcome: {
        category: @outcome_category.to_s,
        direction: @outcome_direction.to_s,
        description: @outcome_description.to_s,
        impact_scope: @impact_scope.to_s,
        evidence_level: @evidence_level.to_s
      },
      insight: {
        insight_type: @insight_type.to_s,
        description: @insight_description.to_s,
        application_note: @application_note.to_s
      },
      source: {
        title: @source_title.to_s,
        url: @source_url.to_s,
        source_type: @source_type.to_s,
        published_on: @source_published_on.to_s
      }
    }
  end

  def record_encounter_case_edit_history(encounter_case, action:, before_snapshot: nil)
    sections = if action == "created"
      created_encounter_case_sections
    else
      changed_encounter_case_sections(before_snapshot, requested_encounter_case_snapshot)
    end

    return if action == "updated" && sections.empty?

    EditHistoryRecorder.record!(
      item: encounter_case,
      action: action,
      summary: history_summary_for(action, sections, fallback: "事例情報"),
      details: { sections: sections }
    )
  end

  def created_encounter_case_sections
    sections = [ "事例情報" ]
    sections << "タグ" if normalized_case_tag_names(@tag_list).any?
    sections << "参加人物" if @participant_names.present?
    sections << "結果" if @outcome_description.present?
    sections << "学び" if @insight_description.present?
    sections << "出典" if @source_url.present?
    sections
  end

  def changed_encounter_case_sections(before_snapshot, after_snapshot)
    sections = []
    sections << "事例情報" if before_snapshot[:attributes] != after_snapshot[:attributes]
    sections << "タグ" if before_snapshot[:tags] != after_snapshot[:tags]
    sections << "参加人物" if before_snapshot[:participants] != after_snapshot[:participants]
    sections << "結果" if before_snapshot[:outcome] != after_snapshot[:outcome]
    sections << "学び" if before_snapshot[:insight] != after_snapshot[:insight]
    sections << "出典" if before_snapshot[:source] != after_snapshot[:source]
    sections
  end

  def normalized_case_tag_names(raw_tag_list)
    raw_tag_list.to_s.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq.sort
  end

  def history_summary_for(action, sections, fallback:)
    target = sections.any? ? sections.join("・") : fallback
    action == "created" ? "#{target}を追加" : "#{target}を更新"
  end
end
