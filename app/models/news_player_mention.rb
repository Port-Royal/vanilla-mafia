class NewsPlayerMention < ApplicationRecord
  belongs_to :news
  belongs_to :player

  validates :player_id, uniqueness: { scope: :news_id }
end
