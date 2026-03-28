class Avo::Resources::PlaylistEpisode < Avo::BaseResource
  self.visible_on_sidebar = false

  def fields
    field :id, as: :id
    field :playlist, as: :belongs_to
    field :episode, as: :belongs_to
    field :position, as: :number, required: true, sortable: true, default: -> { PlaylistEpisode.maximum(:position).to_i + 1 }
  end
end
