class ListRequestsController < ApplicationController
  before_action :require_editor!, only: :index

  def index
    @list_requests = ListRequest.recent
  end

  def new
    @selected_package_key = selected_package_key
    @submitted_list_request = submitted_list_request_from_params
    @list_request = ListRequest.new(default_list_request_attributes(@selected_package_key))
  end

  def create
    @list_request = ListRequest.new(list_request_params)
    @selected_package_key = @list_request.package_key.presence || selected_package_key

    if @list_request.save
      redirect_to new_list_request_path(
        package: @list_request.package_key,
        submitted: @list_request.signed_id(purpose: :list_request_confirmation, expires_in: 7.days)
      ), notice: '依頼を受け付けました。内容確認のうえ、すぐ支払いまたは連絡に進めます。'
    else
      @submitted_list_request = nil
      render :new, status: :unprocessable_entity
    end
  end

  private

  def list_request_params
    params.require(:list_request).permit(
      :requester_name,
      :requester_email,
      :request_theme,
      :request_purpose,
      :package_key,
      :requested_count,
      :delivery_format,
      :budget_range,
      :deadline_preference,
      :note
    )
  end

  def selected_package_key
    requested_key = params[:package].presence || params.dig(:list_request, :package_key).presence
    ListRequest::PACKAGES.key?(requested_key.to_s) ? requested_key.to_s : ListRequest::DEFAULT_PACKAGE_KEY
  end

  def default_list_request_attributes(package_key)
    package = ListRequest.package_for(package_key)

    {
      package_key: package_key,
      requested_count: package[:requested_count],
      delivery_format: package[:delivery_format],
      budget_range: package[:budget_range],
      deadline_preference: package[:deadline_preference]
    }
  end

  def submitted_list_request_from_params
    signed_id = params[:submitted].to_s.presence
    return unless signed_id

    ListRequest.find_signed(signed_id, purpose: :list_request_confirmation)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
