# frozen_string_literal: true

module Admin
  class FamiliesController < Admin::BaseController
    def update
      family = Family.find(params[:id])
      authorize family

      new_code = family_params[:chancen_country_code].presence

      if family.update(chancen_country_code: new_code)
        resync_member_countries(family)
        redirect_to admin_users_path, notice: t(".success")
      else
        redirect_to admin_users_path, alert: family.errors.full_messages.to_sentence
      end
    end

    def destroy
      family = Family.find(params[:id])
      authorize family

      if family.users.exists?
        redirect_to admin_users_path, alert: t(".family_has_users")
        return
      end

      if family.destroy
        redirect_to admin_users_path, notice: t(".success")
      else
        redirect_to admin_users_path, alert: family.errors.full_messages.to_sentence
      end
    end

    private
      def family_params
        params.require(:family).permit(:chancen_country_code)
      end

      # When a family's country is (re)set, bind every member to it: adopt the
      # code and clear consent so they re-accept that country's privacy/terms.
      def resync_member_countries(family)
        code = family.chancen_country_code
        return if code.blank?

        family.users.find_each do |member|
          next if member.country_code == code

          member.update!(
            country_code: code,
            consent_version: nil,
            consent_country_code: nil,
            consent_accepted_at: nil
          )
        end
      end
  end
end
