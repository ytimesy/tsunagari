class CreatePersonExternalProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :person_external_profiles do |t|
      t.references :person, null: false, foreign_key: true
      t.string :source_name, null: false
      t.string :external_id, null: false
      t.string :source_url, null: false
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :fetched_at, null: false

      t.timestamps
    end

    add_index :person_external_profiles, %i[source_name external_id], unique: true
  end
end
