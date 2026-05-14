class AddStubSourceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :stub_source, :string
  end
end
