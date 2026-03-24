class Podcast::PlaybackPositionsController < ApplicationController
  include RequireSubscriber

  def update
    position = PlaybackPosition.find_or_initialize_by(
      user: current_user,
      episode_id: params[:episode_id]
    )
    position.position_seconds = params[:position_seconds]

    if position.save
      render json: { position_seconds: position.position_seconds }
    else
      head :unprocessable_content
    end
  end
end
