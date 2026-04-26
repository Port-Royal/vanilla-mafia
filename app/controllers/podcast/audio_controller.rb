class Podcast::AudioController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_via_token!

  def show
    episode = Episode.visible.find_by(id: params[:episode_id])
    return head(:not_found) unless episode
    return head(:not_found) unless episode.audio.attached?

    redirect_to rails_blob_url(episode.audio, disposition: :inline), allow_other_host: true
  end

  private

  def authenticate_via_token!
    token_value = params[:token]
    head :unauthorized unless token_value && PodcastFeedToken.active.find_by(token: token_value)
  end
end
