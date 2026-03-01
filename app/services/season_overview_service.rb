class SeasonOverviewService
  Result = Data.define(:games_by_series, :players, :player_count)

  def self.call(season:)
    new(season).call
  end

  def initialize(season)
    @season = season
  end

  def call
    Result.new(
      games_by_series: Game.for_season(@season).ordered.group_by(&:series),
      players: Player.with_stats_for_season(@season).ranked,
      # Separate count query for pagy: the `players` relation uses GROUP BY with
      # computed aliases (total_rating, wins_count) that break ActiveRecord's .count,
      # so we count distinct players independently to enable DB-level LIMIT/OFFSET.
      player_count: Player.joins(game_participations: :game).where(games: { season: @season }).distinct.count
    )
  end
end
