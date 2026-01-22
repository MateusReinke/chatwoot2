class AddAuthorTypeToScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :scheduled_messages, :author_type, :string, null: false, default: 'User'
    change_column_default :scheduled_messages, :author_type, from: 'User', to: nil
    remove_foreign_key :scheduled_messages, :users, column: :author_id
  end
end
