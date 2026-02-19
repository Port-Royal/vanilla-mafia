class SeasonOverviewService
  Result = Data.define(:games_by_series, :players)

  def self.call(season:)
    new(season).call
  end

  def initialize(season)
    @season = season
  end

  def call
    Result.new(
      games_by_series: Game.for_season(@season).ordered.group_by(&:series),
      players: Player.with_stats_for_season(@season).ranked
    )
  end
end
