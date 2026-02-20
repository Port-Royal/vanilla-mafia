class Avo::Resources::Award < Avo::BaseResource
  def fields
    field :id, as: :id
    field :title, as: :text
    field :description, as: :textarea
    field :staff, as: :boolean
    field :position, as: :number
    field :icon, as: :file
    field :player_awards, as: :has_many
  end
end
