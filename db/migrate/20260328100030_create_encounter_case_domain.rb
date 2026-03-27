class CreateEncounterCaseDomain < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_cases do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.text :summary
      t.text :background
      t.date :happened_on
      t.string :place
      t.string :publication_status, null: false, default: "draft"
      t.datetime :published_at
      t.references :editor_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :encounter_cases, :slug, unique: true
    add_index :encounter_cases, :publication_status

    create_table :case_participants do |t|
      t.references :encounter_case, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :participation_role, null: false
      t.text :contribution_summary

      t.timestamps
    end
    add_index :case_participants, %i[encounter_case_id person_id participation_role], unique: true, name: "index_case_participants_uniqueness"

    create_table :case_tags do |t|
      t.references :encounter_case, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :case_tags, %i[encounter_case_id tag_id], unique: true

    create_table :case_outcomes do |t|
      t.references :encounter_case, null: false, foreign_key: true
      t.string :category, null: false
      t.text :description, null: false
      t.string :impact_scope
      t.string :evidence_level

      t.timestamps
    end

    create_table :success_factors do |t|
      t.references :encounter_case, null: false, foreign_key: true
      t.string :factor_type, null: false
      t.text :description, null: false
      t.text :reproducibility_note

      t.timestamps
    end
  end
end
