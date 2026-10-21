class PasswordsController < ApplicationController
  layout "settings"

  def edit
  end

  def update
    if Current.user.update(password_params)
      redirect_to root_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def password_params
      permitted = params.require(:user).permit(:password, :password_confirmation, :password_challenge)

      # Accounts without a password (Google/Apple sign-in) set one without a
      # current password, like "Set password" in the mobile app.
      return permitted.except(:password_challenge) unless Current.user.has_local_password?

      permitted.with_defaults(password_challenge: "")
    end
end
