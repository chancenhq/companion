# frozen_string_literal: true

class AddMetadataToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :metadata, :jsonb, default: {}, null: false unless column_exists?(:accounts, :metadata)
  end
end
