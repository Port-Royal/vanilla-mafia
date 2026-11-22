module NewsHelper
  RelatedLink = Data.define(:kind, :label, :path)

  NEWS_PHOTO_VARIANTS = {
    thumbnail: { resize_to_limit: [ 800, 600 ], saver: { quality: 85 } },
    full: { resize_to_limit: [ 1200, 900 ], saver: { quality: 90 } },
    zoom: { resize_to_limit: [ 2400, 1800 ], saver: { quality: 90 } },
    admin_form: { resize_to_limit: [ 400, 400 ], saver: { quality: 80 } },
    card: { resize_to_fill: [ 160, 120 ], saver: { quality: 85 } }
  }.freeze

  def news_photo_variant(photo, variant)
    photo.variant(NEWS_PHOTO_VARIANTS.fetch(variant))
  end

  # What the article is about: its competition, its game, then the players it mentions in the order they were added.
  def news_related_links(news)
    links = []
    competition = news.competition
    links << RelatedLink.new(:competition, competition.name, competition_path(slug: competition.slug)) if competition
    game = news.game
    if game
      label = t("news.redesign.game", competition: game.competition.name, number: game.game_number)
      links << RelatedLink.new(:game, label, game_path(game))
    end
    news.player_mentions.sort_by(&:id).each do |mention|
      links << RelatedLink.new(:player, mention.player.name, player_path(mention.player))
    end
    links
  end
end
