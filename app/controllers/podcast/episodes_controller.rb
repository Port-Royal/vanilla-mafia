class Podcast::EpisodesController < ApplicationController
  include RequireSubscriber

  def index
    @pagy, @episodes = pagy(Episode.published.recent)
  end

  def show
    @episode = Episode.published.find(params[:id])
    playback = PlaybackPosition.find_by(user: current_user, episode: @episode)
    @saved_position = playback ? playback.position_seconds : 0
  end
end
