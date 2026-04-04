class AddQualityFieldsToPeople < ActiveRecord::Migration[7.2]
  def change
    change_table :people, bulk: true do |t|
      t.text :recommended_for
      t.text :meeting_value
      t.text :fit_modes
      t.text :introduction_note
      t.date :last_reviewed_on
    end
  end
end
