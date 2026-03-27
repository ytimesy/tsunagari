class CreateFavorites < ActiveRecord::Migration[7.2]
  def change
    create_table :favorites do |t|
      t.references :owner_user, null: false, foreign_key: { to_table: :users }
      t.references :target_user, null: false, foreign_key: { to_table: :users }

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :favorites, [ :owner_user_id, :target_user_id ], unique: true
    add_check_constraint :favorites,
                         "owner_user_id <> target_user_id",
                         name: "favorites_owner_target_check"
  end
end
