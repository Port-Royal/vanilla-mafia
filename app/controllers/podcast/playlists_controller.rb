class Podcast::PlaylistsController < ApplicationController
  include RequireSubscriber

  def index
    @playlists = Playlist.all
  end

  def show
    @playlist = Playlist.find(params[:id])
  end
end
