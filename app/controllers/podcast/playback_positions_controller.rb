class Podcast::PlaybackPositionsController < ApplicationController
  include RequireSubscriber

  def update
    episode = Episode.visible.find(params[:episode_id])
    position = PlaybackPosition.find_or_initialize_by(
      user: current_user,
      episode: episode
    )
    position.position_seconds = params[:position_seconds]
    position.playback_speed = params[:playback_speed] if params[:playback_speed].present?

    if position.save
      render json: { position_seconds: position.position_seconds, playback_speed: position.playback_speed }
    else
      head :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
