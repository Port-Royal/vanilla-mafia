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
      player_count: Player.joins(ratings: :game).where(games: { season: @season }).distinct.count
    )
  end
end
