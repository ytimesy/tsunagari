class AddPackageKeyToListRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :list_requests, :package_key, :string, default: 'starter_10', null: false
    add_index :list_requests, :package_key
  end
end
