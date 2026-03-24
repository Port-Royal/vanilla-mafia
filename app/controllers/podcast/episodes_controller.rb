class Podcast::EpisodesController < ApplicationController
  include RequireSubscriber

  def index
    @pagy, @episodes = pagy(Episode.published.recent)
  end

  def show
    @episode = Episode.published.find(params[:id])
  end
end
