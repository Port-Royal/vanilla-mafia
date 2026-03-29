class CreatePodcasts < ActiveRecord::Migration[8.1]
  def change
    create_table :podcasts do |t|
      t.string :title, null: false
      t.string :author, null: false
      t.text :description, null: false
      t.string :language, null: false, default: "ru"
      t.string :category

      t.timestamps
    end
  end
end
