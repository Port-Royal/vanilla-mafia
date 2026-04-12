class BackfillGameSlugs < ActiveRecord::Migration[8.1]
  TAIL_BYTES = 2
  MAX_ATTEMPTS = 10

  class MigrationGame < ActiveRecord::Base
    self.table_name = "games"
  end

  class MigrationCompetition < ActiveRecord::Base
    self.table_name = "competitions"
  end

  def up
    MigrationGame.where(slug: nil).find_each do |game|
      competition = MigrationCompetition.find(game.competition_id)
      game.update_column(:slug, unique_slug_for(game, competition))
    end
  end

  def down
    MigrationGame.update_all(slug: nil)
  end

  private

  def base_slug_for(game, competition)
    "#{competition.slug}-game-#{game.game_number}"
  end

  def unique_slug_for(game, competition)
    base = base_slug_for(game, competition)
    candidate = base

    MAX_ATTEMPTS.times do
      return candidate unless MigrationGame.where.not(id: game.id).exists?(slug: candidate)

      candidate = "#{base}-#{SecureRandom.hex(TAIL_BYTES)}"
    end

    raise "Unable to generate unique slug for Game ##{game.id} after #{MAX_ATTEMPTS} attempts"
  end
end
