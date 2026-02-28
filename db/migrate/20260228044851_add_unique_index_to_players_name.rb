class AddUniqueIndexToPlayersName < ActiveRecord::Migration[8.1]
  class MigrationPlayer < ActiveRecord::Base
    self.table_name = "players"
  end

  def up
    # Ensure existing player names are unique before adding the unique index
    say_with_time "Deduplicating player names before adding unique index" do
      # Find all names that appear more than once
      duplicate_names = MigrationPlayer.group(:name)
                                       .having("COUNT(*) > 1")
                                       .pluck(:name)

      duplicate_names.each do |dup_name|
        players_with_name = MigrationPlayer.where(name: dup_name).order(:id)

        # Keep the first record's name; adjust the rest to be unique
        players_with_name.offset(1).each_with_index do |player, index|
          base_name = player.name
          suffix_counter = index + 2
          new_name = "#{base_name} (#{suffix_counter})"

          # Ensure the new name is globally unique across all players
          while MigrationPlayer.exists?(name: new_name)
            suffix_counter += 1
            new_name = "#{base_name} (#{suffix_counter})"
          end

          player.update_columns(name: new_name)
        end
      end
    end

    add_index :players, :name, unique: true
  end

  def down
    remove_index :players, :name
  end
end
