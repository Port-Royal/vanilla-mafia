class Avo::Resources::PlayerAward < Avo::BaseResource
  def fields
    field :id, as: :id
    field :player, as: :belongs_to
    field :award, as: :belongs_to
    field :season, as: :number
    field :position, as: :number
  end
end
