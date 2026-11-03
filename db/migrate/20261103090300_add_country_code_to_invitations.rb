class AddCountryCodeToInvitations < ActiveRecord::Migration[7.2]
  def change
    add_column :invitations, :country_code, :string, if_not_exists: true
  end
end
