class HomeController < ApplicationController
  MINI_STANDINGS_LIMIT = 5
  RECENTLY_FINISHED_LIMIT = 3
  RECENT_GAMES_LIMIT = 5
  LATEST_NEWS_LIMIT = 3
  HALL_OF_FAME_LIMIT = 6

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

    @recent_games = Game.finished.recent.includes(competition: :parent).limit(RECENT_GAMES_LIMIT) if @block_visible[:recent_games]
    @latest_news = News.published.recent.limit(LATEST_NEWS_LIMIT) if @block_visible[:latest_news]
    @hall_of_fame_players = load_hall_of_fame_players if @block_visible[:hall_of_fame]
    @stats = load_stats if @block_visible[:stats]
    @announcements = load_announcements
  end

  private

  BLOCK_KEYS = %i[hero whats_new running_tournaments recently_finished recent_games latest_news hall_of_fame stats documents].freeze

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

  def load_stats
    {
      players: Player.count,
      games: Game.finished.count,
      competitions: Competition.roots.finished.count
    }
  end

  def load_announcements
    return unless user_signed_in?
    return unless FeatureToggle.enabled?("home_whats_new") || FeatureToggle.enabled?("toast_whats_new")

    Announcement.for_user(current_user)
  end

  def load_hall_of_fame_players
    Player
      .joins(:player_awards)
      .merge(PlayerAward.joins(:award).where(awards: { staff: false }))
      .distinct
      .includes(photo_attachment: :blob)
      .limit(HALL_OF_FAME_LIMIT)
  end
end
