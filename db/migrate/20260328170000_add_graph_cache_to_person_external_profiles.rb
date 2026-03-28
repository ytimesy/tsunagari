class AddGraphCacheToPersonExternalProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :person_external_profiles, :graph_tags, :text, array: true, default: [], null: false
    add_column :person_external_profiles, :graph_organizations, :text, array: true, default: [], null: false
  end
end
