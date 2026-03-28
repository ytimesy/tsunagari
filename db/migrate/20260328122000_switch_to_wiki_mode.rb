class SwitchToWikiMode < ActiveRecord::Migration[7.2]
  def up
    remove_reference :encounter_cases, :editor_user, foreign_key: { to_table: :users }, index: true
    remove_reference :research_notes, :author_user, foreign_key: { to_table: :users }, index: true
    drop_table :users
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "wiki mode migration cannot be rolled back automatically"
  end
end
