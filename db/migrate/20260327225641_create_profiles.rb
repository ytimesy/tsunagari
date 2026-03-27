class CreateProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :display_name, null: false
      t.text :bio
      t.string :organization
      t.string :role
      t.string :visibility_level, null: false, default: "member"

      t.timestamps
    end

    add_check_constraint :profiles,
                         "visibility_level IN ('public', 'member', 'private')",
                         name: "profiles_visibility_level_check"
  end
end
