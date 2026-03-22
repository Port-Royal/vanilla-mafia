class GameProtocolChannel < ApplicationCable::Channel
  def subscribed
    game = Game.find_by(id: params.fetch(:game_id))

    if game
      stream_for game
    else
      reject
    end
  end
end
