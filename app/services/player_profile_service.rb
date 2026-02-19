class PlayerProfileService
  Result = Data.define(:player, :games_by_season, :player_awards)

  def self.call(player_id:)
    new(player_id).call
  end

  def initialize(player_id)
    @player_id = player_id
  end

  def call
    player = Player.find(@player_id)
    Result.new(
      player: player,
      games_by_season: player.games.ordered.group_by(&:season),
      player_awards: player.player_awards.ordered.includes(:award).load
    )
  end
end
