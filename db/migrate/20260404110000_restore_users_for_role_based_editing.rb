class RestoreUsersForRoleBasedEditing < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: 'editor'
      t.string :status, null: false, default: 'active'

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
