class MemberSignupsController < ApplicationController
  def new
    return redirect_to(root_path, notice: "すでにログインしています。") if deep_insight_access?

    @return_to = params[:return_to].presence || root_path
    @member = User.new
  end

  def create
    @return_to = sanitized_return_to(params[:return_to])
    @member = User.new(member_signup_params.merge(role: "member", status: "active"))

    if @member.save
      session[:user_id] = @member.id
      redirect_to @return_to, notice: "Insightの利用登録が完了しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def member_signup_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def sanitized_return_to(value)
    candidate = value.to_s
    return root_path if candidate.blank?
    return root_path unless candidate.start_with?("/")
    return root_path if candidate.start_with?("//")

    candidate
  end
end
