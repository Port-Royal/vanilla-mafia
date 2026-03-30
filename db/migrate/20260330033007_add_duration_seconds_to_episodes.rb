class AddDurationSecondsToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :duration_seconds, :integer
  end
end
