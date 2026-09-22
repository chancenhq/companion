class AddConfirmedAtToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :confirmed_at, :datetime
    User.update_all(confirmed_at: Time.current)
  end

  def down
    remove_column :users, :confirmed_at
  end
end
