class MakeEncounterCasesFailureAware < ActiveRecord::Migration[7.2]
  def up
    add_column :case_outcomes, :outcome_direction, :string, null: false, default: "positive"

    rename_table :success_factors, :case_insights
    rename_column :case_insights, :factor_type, :insight_type
    rename_column :case_insights, :reproducibility_note, :application_note
    old_index = "index_success_factors_on_encounter_case_id"
    new_index = "index_case_insights_on_encounter_case_id"
    rename_index :case_insights, old_index, new_index if index_name_exists?(:case_insights, old_index)
  end

  def down
    new_index = "index_case_insights_on_encounter_case_id"
    old_index = "index_success_factors_on_encounter_case_id"
    rename_index :case_insights, new_index, old_index if index_name_exists?(:case_insights, new_index)
    rename_column :case_insights, :application_note, :reproducibility_note
    rename_column :case_insights, :insight_type, :factor_type
    rename_table :case_insights, :success_factors

    remove_column :case_outcomes, :outcome_direction
  end
end
