class Avo::Resources::Playlist < Avo::BaseResource
  self.title = :title
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("title ILIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :title, as: :text, required: true, sortable: true
    field :playlist_episodes, as: :has_many
  end
end
