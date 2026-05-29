class Avo::Resources::Playlist < Avo::BaseResource
  self.title = :title

  def self.navigation_label = "Podcast: Playlists"
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("LOWER(title) LIKE LOWER(?)", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :title, as: :text, required: true, sortable: true
    field :playlist_episodes, as: :has_many
  end
end
