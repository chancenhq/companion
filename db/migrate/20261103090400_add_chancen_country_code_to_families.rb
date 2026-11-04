class AddChancenCountryCodeToFamilies < ActiveRecord::Migration[8.1]
  def change
    add_column :families, :chancen_country_code, :string, if_not_exists: true
  end
end
