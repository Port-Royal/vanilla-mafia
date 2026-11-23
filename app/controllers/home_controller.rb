class HomeController < ApplicationController
  MINI_STANDINGS_LIMIT = 5
  RECENTLY_FINISHED_LIMIT = 3
  RECENT_GAMES_LIMIT = 5
  LATEST_NEWS_LIMIT = 3

  def index
    @block_visible = load_block_visibility
    @running_competitions = Competition.roots.running.ordered

    if @block_visible[:running_tournaments]
      @mini_standings = load_mini_standings(@running_competitions)
    end

    if @block_visible[:recently_finished]
      @recently_finished = Competition.roots.recently_finished.limit(RECENTLY_FINISHED_LIMIT)
      @winners = load_winners(@recently_finished)
    end

    @recent_games = Game.finished.recent.includes(competition: :parent).limit(RECENT_GAMES_LIMIT).load if @block_visible[:recent_games]
    @latest_news = load_news_cards if @block_visible[:latest_news]
    @announcements = load_announcements
  end

  private

  BLOCK_KEYS = %i[running_tournaments recently_finished recent_games latest_news].freeze

  # News cards show each article's photo, author and excerpt, so those are preloaded.
  def load_news_cards
    News.visible.recent.with_attached_photos.includes(:rich_text_content, author: :player).limit(LATEST_NEWS_LIMIT).load
  end

  def load_block_visibility
    BLOCK_KEYS.index_with { |key| !FeatureToggle.disabled?("home_#{key}") }
  end

  def load_mini_standings(competitions)
    competitions.index_with do |competition|
      Player.with_stats_for_competition(competition).ranked.limit(MINI_STANDINGS_LIMIT)
    end
  end

  def load_winners(competitions)
    competitions.index_with do |competition|
      Player.with_stats_for_competition(competition).ranked.first
    end
  end

  # Release notes reach this page only through the toast.
  def load_announcements
    return unless user_signed_in?
    return unless FeatureToggle.enabled?("toast_whats_new")

    Announcement.for_user(current_user)
  end
end
