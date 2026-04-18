class GameProtocolChannel < ApplicationCable::Channel
  def subscribed
    game = Game.find_by(id: params[:game_id])

    if game && authorized?(game)
      stream_for game
    else
      reject
    end
  end

  private

  def authorized?(game)
    return true if game.in_progress?

    current_user && current_user.can_manage_protocols?
  end
end
