class Podcast::PlaybackPositionsController < ApplicationController
  include RequireSubscriber

  def update
    episode = Episode.published.find(params[:episode_id])
    position = PlaybackPosition.find_or_initialize_by(
      user: current_user,
      episode: episode
    )
    position.position_seconds = params[:position_seconds]

    if position.save
      render json: { position_seconds: position.position_seconds }
    else
      head :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
