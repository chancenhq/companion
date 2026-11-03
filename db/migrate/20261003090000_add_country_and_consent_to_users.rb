class AddCountryAndConsentToUsers < ActiveRecord::Migration[7.2]
  # Issue #106, Epic 1. The member's own country (not the household country,
  # which defaults to "US"), validated against config/chancen_countries.yml
  # rather than a database constraint so adding a country is a config change.
  # Consent records which privacy/terms version was accepted, for which
  # country, and when.
  def change
    add_column :users, :country_code, :string
    add_column :users, :consent_version, :string
    add_column :users, :consent_country_code, :string
    add_column :users, :consent_accepted_at, :datetime
    add_index :users, :country_code
  end
end
