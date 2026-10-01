class AddCountryAndEmailVerificationToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :country_code, :string
    add_column :users, :email_verified_at, :datetime

    execute <<~SQL.squish
      UPDATE users
      SET email_verified_at = COALESCE(users.created_at, CURRENT_TIMESTAMP)
      WHERE EXISTS (
        SELECT 1
        FROM oidc_identities
        WHERE oidc_identities.user_id = users.id
          AND oidc_identities.provider IN ('google_oauth2', 'apple')
      )
    SQL

    add_index :users, :country_code
    add_check_constraint :users,
                         "country_code IS NULL OR country_code IN ('KE', 'RW', 'ZA', 'GH')",
                         name: "users_country_code_supported"
  end

  def down
    remove_check_constraint :users, name: "users_country_code_supported"
    remove_index :users, :country_code
    remove_column :users, :email_verified_at
    remove_column :users, :country_code
  end
end
