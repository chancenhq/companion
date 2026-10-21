# The Chancen Account (ISA summary and payments) lives in the Companion mobile
# app for now. These pages keep the web navigation in step with the app until
# web versions are designed.
class MyAccountsController < ApplicationController
  def show
    @breadcrumbs = [ [ t("breadcrumbs.home"), chats_path ], [ t(".title"), nil ] ]
  end

  def payments
    @breadcrumbs = [ [ t("breadcrumbs.home"), chats_path ], [ t(".title"), nil ] ]
  end
end
