class CreateListRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :list_requests do |t|
      t.string :requester_name, null: false
      t.string :requester_email, null: false
      t.string :request_theme, null: false
      t.text :request_purpose
      t.integer :requested_count, null: false, default: 10
      t.string :delivery_format
      t.string :budget_range
      t.string :deadline_preference
      t.text :note
      t.string :status, null: false, default: 'new'
      t.string :payment_status, null: false, default: 'pending'

      t.timestamps
    end

    add_index :list_requests, :status
    add_index :list_requests, :payment_status
    add_index :list_requests, :created_at
  end
end
