class AddSummaryToBreakdownSpeeches < ActiveRecord::Migration[8.1]
  def change
    add_column :breakdown_speeches, :summary, :text
  end
end
