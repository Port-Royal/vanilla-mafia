class Podcast::EpisodesController < ApplicationController
  include RequireSubscriber

  def index
    @pagy, @episodes = pagy(Episode.published.recent)
    @feed_token = current_user.podcast_feed_token || current_user.create_podcast_feed_token!
  end

  def show
    @episode = Episode.published.find(params[:id])
    playback = PlaybackPosition.find_by(user: current_user, episode: @episode)
    @saved_position = playback ? playback.position_seconds : 0
    @saved_speed = playback ? playback.playback_speed : 1.0
  end
end
