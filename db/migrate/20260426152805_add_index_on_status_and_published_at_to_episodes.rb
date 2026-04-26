class AddIndexOnStatusAndPublishedAtToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_index :episodes, [ :status, :published_at ]
  end
end
