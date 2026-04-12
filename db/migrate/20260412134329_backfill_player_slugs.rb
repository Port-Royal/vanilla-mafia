class BackfillPlayerSlugs < ActiveRecord::Migration[8.1]
  def up
    Player.where(slug: nil).find_each do |player|
      base = CyrillicTransliterator.call(player.name.to_s).parameterize.presence ||
             SecureRandom.hex(2)
      candidate = base
      Sluggable::MAX_SLUG_ATTEMPTS.times do
        unless Player.where.not(id: player.id).exists?(slug: candidate)
          player.update_column(:slug, candidate)
          break
        end
        candidate = "#{base}-#{SecureRandom.hex(Sluggable::TAIL_BYTES)}"
      end
      player.update_column(:slug, candidate) if player.reload.slug.nil?
    end
  end

  def down
    Player.update_all(slug: nil)
  end
end
