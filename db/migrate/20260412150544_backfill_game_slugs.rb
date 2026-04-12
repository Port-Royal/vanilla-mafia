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
    MigrationGame.where(slug: nil).in_batches do |batch|
      competition_ids = batch.pluck(:competition_id).uniq
      competitions_by_id = MigrationCompetition.where(id: competition_ids).index_by(&:id)

      batch.each do |game|
        competition = competitions_by_id.fetch(game.competition_id)
        game.update_column(:slug, unique_slug_for(game, competition))
      end
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
