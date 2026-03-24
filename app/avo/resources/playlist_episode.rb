class Avo::Resources::PlaylistEpisode < Avo::BaseResource
  def fields
    field :id, as: :id
    field :playlist, as: :belongs_to
    field :episode, as: :belongs_to
    field :position, as: :number, required: true, sortable: true
  end
end
