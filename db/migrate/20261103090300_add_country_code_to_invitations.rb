class AddCountryCodeToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :invitations, :country_code, :string, if_not_exists: true
  end
end
