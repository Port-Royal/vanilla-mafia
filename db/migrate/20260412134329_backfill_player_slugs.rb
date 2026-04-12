class BackfillPlayerSlugs < ActiveRecord::Migration[8.1]
  CYRILLIC_TABLE = {
    "а" => "a", "б" => "b", "в" => "v", "г" => "g", "д" => "d", "е" => "e", "ё" => "yo",
    "ж" => "zh", "з" => "z", "и" => "i", "й" => "y", "к" => "k", "л" => "l", "м" => "m",
    "н" => "n", "о" => "o", "п" => "p", "р" => "r", "с" => "s", "т" => "t", "у" => "u",
    "ф" => "f", "х" => "kh", "ц" => "ts", "ч" => "ch", "ш" => "sh", "щ" => "shch",
    "ъ" => "", "ы" => "y", "ь" => "", "э" => "e", "ю" => "yu", "я" => "ya"
  }.freeze

  TAIL_BYTES = 2
  MAX_ATTEMPTS = 10

  class MigrationPlayer < ActiveRecord::Base
    self.table_name = "players"
  end

  def up
    MigrationPlayer.where(slug: nil).find_each do |player|
      player.update_column(:slug, unique_slug_for(player))
    end
  end

  def down
    MigrationPlayer.update_all(slug: nil)
  end

  private

  def transliterate(string)
    string.to_s.each_char.map { |c| CYRILLIC_TABLE[c.downcase] || c }.join
  end

  def base_slug_for(name)
    transliterate(name).parameterize.presence || SecureRandom.hex(TAIL_BYTES)
  end

  def unique_slug_for(player)
    base = base_slug_for(player.name)
    candidate = base

    MAX_ATTEMPTS.times do
      return candidate unless MigrationPlayer.where.not(id: player.id).exists?(slug: candidate)

      candidate = "#{base}-#{SecureRandom.hex(TAIL_BYTES)}"
    end

    raise "Unable to generate unique slug for Player ##{player.id} after #{MAX_ATTEMPTS} attempts"
  end
end
