class CreateEncounterNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_notes do |t|
      t.references :author_user, null: false, foreign_key: { to_table: :users }
      t.references :subject_user, null: false, foreign_key: { to_table: :users }
      t.date :encountered_on
      t.string :encounter_place
      t.text :note, null: false
      t.text :next_action

      t.timestamps
    end

    add_index :encounter_notes, [ :author_user_id, :subject_user_id ]
  end
end
