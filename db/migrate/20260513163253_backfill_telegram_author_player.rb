class BackfillTelegramAuthorPlayer < ActiveRecord::Migration[8.1]
  class MigrationTelegramAuthor < ActiveRecord::Base
    self.table_name = "telegram_authors"
  end

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    MigrationTelegramAuthor.where(player_id: nil).where.not(user_id: nil).in_batches do |batch|
      user_ids = batch.pluck(:user_id)
      players_by_user_id = MigrationUser.where(id: user_ids).pluck(:id, :player_id).to_h

      batch.each do |author|
        player_id = players_by_user_id[author.user_id]
        author.update_column(:player_id, player_id) if player_id.present?
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
