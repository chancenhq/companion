class AddChancenCountryCodeToFamilies < ActiveRecord::Migration[7.2]
  def change
    add_column :families, :chancen_country_code, :string
  end
end
