class ListRequestsController < ApplicationController
  before_action :require_editor!, only: :index

  def index
    @list_requests = ListRequest.recent
  end

  def new
    @list_request = ListRequest.new(
      requested_count: 10,
      delivery_format: ListRequest::DELIVERY_FORMATS.second,
      budget_range: ListRequest::BUDGET_RANGES.second,
      deadline_preference: ListRequest::DEADLINE_PREFERENCES.second
    )
  end

  def create
    @list_request = ListRequest.new(list_request_params)

    if @list_request.save
      redirect_to new_list_request_path, notice: '依頼を受け付けました。内容を確認して連絡します。'
    else
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
      :requested_count,
      :delivery_format,
      :budget_range,
      :deadline_preference,
      :note
    )
  end
end
