# frozen_string_literal: true

module Admin
  class FamiliesController < Admin::BaseController
    def index
      @families = Family.order(:name)
    end

    def edit
      @family = Family.find(params[:id])
    end

    def update
      @family = Family.find(params[:id])
      @family.update!(family_params)
      redirect_to admin_families_path, notice: t(".success")
    end

    private
      def family_params
        params.require(:family).permit(:chancen_country_code)
      end
  end
end
