class RemoveRawPayloadFromPersonExternalProfiles < ActiveRecord::Migration[7.2]
  def change
    remove_column :person_external_profiles, :raw_payload, :jsonb, default: {}, null: false
  end
end
