class EmailConfirmationsController < ApplicationController
  skip_before_action :set_request_details, only: :new
  skip_authentication only: :new

  def new
    # Returns nil if the token is invalid OR expired
    @user = User.find_by_token_for(:email_confirmation, params[:token])

    if @user&.unconfirmed_email && @user.confirm_email!
      redirect_to new_session_path, notice: t(".success_login")
    else
      redirect_to root_path, alert: t(".invalid_token")
    end
  end
end
