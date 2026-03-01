class Avo::Resources::Role < Avo::BaseResource
  def fields
    field :code, as: :id
    field :name, as: :text
    field :game_participations, as: :has_many
  end
end
