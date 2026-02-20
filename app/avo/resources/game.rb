class Avo::Resources::Game < Avo::BaseResource
  def fields
    field :id, as: :id
    field :season, as: :number
    field :series, as: :number
    field :game_number, as: :number
    field :played_on, as: :date
    field :name, as: :text
    field :result, as: :text
    field :ratings, as: :has_many
  end
end
