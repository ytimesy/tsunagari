class CreateProfileTags < ActiveRecord::Migration[7.2]
  def change
    create_table :profile_tags do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :profile_tags, [ :profile_id, :tag_id ], unique: true
  end
end
