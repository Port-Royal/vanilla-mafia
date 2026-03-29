class Podcast::AudioController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_via_token!

  def show
    episode = Episode.published.find_by(id: params[:episode_id])
    head :not_found and return unless episode
    head :not_found and return unless episode.audio.attached?

    redirect_to rails_blob_url(episode.audio, disposition: :inline), allow_other_host: true
  end

  private

  def authenticate_via_token!
    token_value = params[:token]
    head :unauthorized unless token_value && PodcastFeedToken.active.find_by(token: token_value)
  end
end
