class PasswordMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @subject = t(".subject", product_name: product_name)
    @cta = t(".cta")

    mail to: @user.email, subject: @subject
  end

  def mobile_password_reset
    @user = params[:user]
    @reset_url = "sureapp://password-reset?token=#{params[:token]}"
    @subject = t("password_mailer.password_reset.subject", product_name: product_name)

    mail to: @user.email, subject: @subject
  end
end
