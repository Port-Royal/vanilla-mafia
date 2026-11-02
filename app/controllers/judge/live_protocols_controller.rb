class Judge::LiveProtocolsController < Judge::LiveProtocolBaseController
  def show
    @players = @game.game_participations.includes(:player).where.not(seat: nil).order(:seat).map do |participation|
      { seat: participation.seat, name: participation.player.name, role_code: participation.role_code, status: participation.status }
    end
    @events = @game.game_protocol_events.order(:position)
  end
end
