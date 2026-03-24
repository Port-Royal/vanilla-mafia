class CreateEpisodes < ActiveRecord::Migration[8.1]
  def change
    create_table :episodes do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.datetime :published_at

      t.timestamps
    end
  end
end
