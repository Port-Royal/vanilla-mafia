class Podcast::EpisodesController < ApplicationController
  include RequireSubscriber

  def index
    @episodes = Episode.published.recent
  end

  def show
    @episode = Episode.published.find(params[:id])
  end
end
