class CreateTagsAndPeopleTags < ActiveRecord::Migration[7.2]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false

      t.timestamps
    end
    add_index :tags, :normalized_name, unique: true

    create_table :person_tags do |t|
      t.references :person, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :person_tags, %i[person_id tag_id], unique: true
  end
end
