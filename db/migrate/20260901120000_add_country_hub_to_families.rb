class AddCountryHubToFamilies < ActiveRecord::Migration[8.0]
  def change
    add_column :families, :country_hub, :boolean, default: false, null: false
    add_index  :families, [ :country, :country_hub ]
  end
end
