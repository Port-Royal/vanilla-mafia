class BackfillNewsSlugs < ActiveRecord::Migration[8.1]
  CYRILLIC_TABLE = {
    "а" => "a", "б" => "b", "в" => "v", "г" => "g", "д" => "d", "е" => "e", "ё" => "yo",
    "ж" => "zh", "з" => "z", "и" => "i", "й" => "y", "к" => "k", "л" => "l", "м" => "m",
    "н" => "n", "о" => "o", "п" => "p", "р" => "r", "с" => "s", "т" => "t", "у" => "u",
    "ф" => "f", "х" => "kh", "ц" => "ts", "ч" => "ch", "ш" => "sh", "щ" => "shch",
    "ъ" => "", "ы" => "y", "ь" => "", "э" => "e", "ю" => "yu", "я" => "ya"
  }.freeze

  TAIL_BYTES = 2
  MAX_ATTEMPTS = 10
  SLUG_TITLE_LIMIT = 80

  class MigrationNews < ActiveRecord::Base
    self.table_name = "news"
  end

  def up
    MigrationNews.where(slug: nil).find_each do |news|
      MigrationNews.where(id: news.id).update_all(slug: unique_slug_for(news))
    end
  end

  def down
    MigrationNews.update_all(slug: nil)
  end

  private

  def transliterate(string)
    string.to_s.each_char.map { |c| CYRILLIC_TABLE[c.downcase] || c }.join
  end

  def title_part_for(title)
    transliterated = transliterate(title).parameterize
    truncated = transliterated.truncate(SLUG_TITLE_LIMIT, separator: "-", omission: "").delete_suffix("-")
    truncated.presence || SecureRandom.hex(TAIL_BYTES)
  end

  def base_slug_for(news)
    date = news.published_at || news.created_at || Time.current
    "#{date.strftime('%Y-%m-%d')}-#{title_part_for(news.title)}"
  end

  def unique_slug_for(news)
    base = base_slug_for(news)
    candidate = base

    MAX_ATTEMPTS.times do
      return candidate unless MigrationNews.where.not(id: news.id).exists?(slug: candidate)

      candidate = "#{base}-#{SecureRandom.hex(TAIL_BYTES)}"
    end

    raise "Unable to generate unique slug for News ##{news.id} after #{MAX_ATTEMPTS} attempts"
  end
end
