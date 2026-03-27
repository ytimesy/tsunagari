class ProfilesController < ApplicationController
  before_action :require_authentication
  before_action :set_profile

  def show
    @favorites_count = current_user.favorites.count
    @encounter_notes_count = current_user.authored_encounter_notes.count
  end

  def edit
    @tag_list = @profile.tags.order(:name).pluck(:name).join(", ")
  end

  def update
    @tag_list = profile_params[:tag_list].to_s

    ActiveRecord::Base.transaction do
      @profile.update!(profile_params.except(:tag_list))
      sync_tags(@profile, @tag_list)
    end

    redirect_to profile_path, notice: "編集プロフィールを更新しました。"
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private

  def set_profile
    @profile = current_user.profile || current_user.create_profile!(display_name: current_user.email.split("@").first)
  end

  def profile_params
    params.require(:profile).permit(:display_name, :bio, :organization, :role, :visibility_level, :tag_list)
  end

  def sync_tags(profile, raw_tag_list)
    tag_names = raw_tag_list.split(",").map { |name| name.strip.squish }.reject(&:blank?).uniq
    profile.tags = tag_names.map { |name| Tag.find_or_initialize_by(normalized_name: name.downcase).tap { |tag| tag.name = name } }
  end
end
