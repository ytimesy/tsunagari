class CreatePeopleAndOrganizations < ActiveRecord::Migration[7.2]
  def change
    create_table :people do |t|
      t.string :slug, null: false
      t.string :display_name, null: false
      t.text :summary
      t.text :bio
      t.string :publication_status, null: false, default: "draft"
      t.datetime :published_at

      t.timestamps
    end
    add_index :people, :slug, unique: true
    add_index :people, :publication_status

    create_table :organizations do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :category
      t.string :website_url

      t.timestamps
    end
    add_index :organizations, :slug, unique: true

    create_table :person_affiliations do |t|
      t.references :person, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :title
      t.date :started_on
      t.date :ended_on
      t.boolean :primary_flag, null: false, default: false

      t.timestamps
    end
    add_index :person_affiliations, %i[person_id organization_id title started_on], unique: true, name: "index_person_affiliations_uniqueness"
  end
end
