class CreateSourcesAndResearchNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :sources do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.string :source_type
      t.date :published_on

      t.timestamps
    end
    add_index :sources, :url, unique: true

    create_table :case_sources do |t|
      t.references :encounter_case, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true
      t.string :citation_note

      t.timestamps
    end
    add_index :case_sources, %i[encounter_case_id source_id], unique: true

    create_table :research_notes do |t|
      t.references :author_user, null: false, foreign_key: { to_table: :users }
      t.references :person, foreign_key: true
      t.references :encounter_case, foreign_key: true
      t.string :note_kind, null: false, default: "research"
      t.text :body, null: false
      t.string :status, null: false, default: "open"

      t.timestamps
    end
    add_index :research_notes, :status
  end
end
