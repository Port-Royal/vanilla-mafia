class Podcast::PlaylistsController < ApplicationController
  include RequireSubscriber

  def index
    @playlists = Playlist.includes(:playlist_episodes).all
  end

  def show
    @playlist = Playlist.includes(playlist_episodes: :episode).find(params[:id])
  end
end
