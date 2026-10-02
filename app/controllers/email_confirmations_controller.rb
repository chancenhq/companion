class EmailConfirmationsController < ApplicationController
  skip_before_action :set_request_details, only: :new
  skip_authentication only: :new

  def new
    # Returns nil if the token is invalid OR expired
    @user = User.find_by_token_for(:email_confirmation, params[:token])

    if @user.nil?
      redirect_to root_path, alert: t(".invalid_token")
    elsif @user.pending_email_change?
      # Confirming an email change also verifies the new address.
      if @user.update(email: @user.unconfirmed_email, unconfirmed_email: nil, email_verified_at: Time.current)
        redirect_to new_session_path, notice: t(".success_login")
      else
        redirect_to root_path, alert: t(".invalid_token")
      end
    else
      # Initial sign-up verification (issue #106).
      @user.mark_email_verified!
      redirect_to new_session_path, notice: t(".verified")
    end
  end
end
