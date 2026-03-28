class EncounterCasesController < ApplicationController
  before_action :set_encounter_case, only: %i[show edit update]
  before_action :prepare_form_fields, only: %i[new edit]

  def index
    @query = params[:q].to_s.strip
    @encounter_cases = base_scope
    @encounter_cases = apply_search(@encounter_cases, @query) if @query.present?
    @encounter_cases = @encounter_cases.order(happened_on: :desc, published_at: :desc, created_at: :desc)
  end

  def show
    @research_notes = @encounter_case.research_notes.order(created_at: :desc)
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
    end

    redirect_to @encounter_case, notice: "出会い事例を作成しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    assign_form_values_from_params
    validate_publish_requirements!

    ActiveRecord::Base.transaction do
      @encounter_case.update!(encounter_case_attributes)
      sync_tags(@encounter_case, @tag_list)
      sync_participants(@encounter_case)
      sync_outcomes(@encounter_case)
      sync_case_insights(@encounter_case)
      sync_sources(@encounter_case)
    end

    redirect_to @encounter_case, notice: "出会い事例を更新しました。"
  rescue ActiveRecord::RecordInvalid
    prepare_form_fields
    render :edit, status: :unprocessable_entity
  end

  private

  def set_encounter_case
    @encounter_case = EncounterCase.includes(:people, :case_outcomes, :case_insights, :sources, :tags).find_by!(slug: params[:slug])
  end

  def base_scope
    EncounterCase.includes(:people, :case_outcomes, :sources, :tags)
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
end
