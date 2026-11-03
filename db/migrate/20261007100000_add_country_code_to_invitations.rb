class AddCountryCodeToInvitations < ActiveRecord::Migration[7.2]
  def change
    add_column :invitations, :country_code, :string
  end
end
