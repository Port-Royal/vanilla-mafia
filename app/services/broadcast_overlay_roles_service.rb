class BroadcastOverlayRolesService
  def self.call(game:)
    new(game).call
  end

  def initialize(game)
    @game = game
  end

  def call
    GameProtocolChannel.broadcast_to(@game, { scope: "game", field: "hide_roles", value: "0" })

    @game.game_participations.where.not(seat: nil).order(:seat).each do |participation|
      GameProtocolChannel.broadcast_to(@game, { scope: "participation", seat: participation.seat, field: "role_code", value: participation.role_code })
    end
  end
end
