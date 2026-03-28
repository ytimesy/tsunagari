require_dependency Rails.root.join("app/services/external_people/error").to_s
require_dependency Rails.root.join("app/services/external_people/base_client").to_s
require_dependency Rails.root.join("app/services/external_people/provider_registry").to_s
require_dependency Rails.root.join("app/services/external_people/wikidata_client").to_s
require_dependency Rails.root.join("app/services/external_people/open_alex_client").to_s
require_dependency Rails.root.join("app/services/external_people/importer").to_s
require_dependency Rails.root.join("app/services/edit_history_recorder").to_s

class PersonImportsController < ApplicationController
  def new
    @source_name = normalized_source_name(params[:source_name])
    @query = params[:q].to_s.strip
    @target_person = Person.find_by(id: params[:person_id]) if params[:person_id].present?
    @results = []
    @existing_profiles = {}

    return if @query.blank?

    @results = provider_for(@source_name).search(@query)
    @existing_profiles = PersonExternalProfile.includes(:person).where(
      source_name: @source_name,
      external_id: @results.map { |result| result[:external_id] }
    ).index_by(&:external_id)
  rescue ExternalPeople::Error => error
    @results = []
    flash.now[:alert] = error.message
  end

  def create
    source_name = normalized_source_name(import_params[:source_name])
    target_person = Person.find_by(id: import_params[:person_id]) if import_params[:person_id].present?
    profile = provider_for(source_name).fetch_profile(import_params[:external_id])
    person = ExternalPeople::Importer.import!(profile: profile, target_person: target_person)
    EditHistoryRecorder.record!(
      item: person,
      action: "imported",
      summary: "#{source_label_for(source_name)} から外部情報を取り込み",
      details: { source_name: source_name, external_id: import_params[:external_id].to_s }
    )

    redirect_to person_path(person), notice: target_person.present? ? "既存の人物に外部データを取り込みました。" : "外部データから人物を取り込みました。"
  rescue ExternalPeople::Error => error
    redirect_to new_person_import_path(
      source_name: import_params[:source_name],
      q: import_params[:q],
      person_id: import_params[:person_id]
    ), alert: error.message
  end

  private

  def import_params
    params.permit(:source_name, :external_id, :q, :person_id)
  end

  def normalized_source_name(value)
    value.to_s.in?(PersonExternalProfile::SOURCES) ? value.to_s : "wikidata"
  end

  def provider_for(source_name)
    ExternalPeople::ProviderRegistry.provider_for(source_name)
  end

  def source_label_for(source_name)
    {
      "wikidata" => "Wikidata",
      "openalex" => "OpenAlex"
    }.fetch(source_name, source_name)
  end
end
