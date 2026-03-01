class SeriesAggregationService
  Result = Data.define(:games, :participations_by_player, :players_sorted)

  def self.call(season:, series:)
    new(season, series).call
  end

  def initialize(season, series)
    @season = season
    @series = series
  end

  def call
    games = Game.for_season(@season).where(series: @series).ordered
    participations_by_player = GameParticipation.where(game: games).includes(:player).group_by(&:player)
    players_sorted = participations_by_player.keys.sort_by { |p| [ -participations_by_player[p].sum(&:total), p.id ] }

    Result.new(games:, participations_by_player:, players_sorted:)
  end
end
