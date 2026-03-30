class Podcast::FeedController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_via_token!

  def show
    @podcast = Podcast.instance
    @episodes = Episode.published.recent.includes(:audio_attachment)
    @token = params[:token]
    render formats: :rss
  end

  private

  def authenticate_via_token!
    token_value = params[:token]
    head :unauthorized unless token_value && PodcastFeedToken.active.find_by(token: token_value)
  end
end
