class CreateEditHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :edit_histories do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :action, null: false
      t.string :summary, null: false
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :edit_histories, %i[item_type item_id created_at]
  end
end
