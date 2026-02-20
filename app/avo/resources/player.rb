class Avo::Resources::Player < Avo::BaseResource
  def fields
    field :id, as: :id
    field :name, as: :text
    field :position, as: :number
    field :comment, as: :textarea
    field :photo, as: :file
    field :ratings, as: :has_many
    field :player_awards, as: :has_many
  end
end
