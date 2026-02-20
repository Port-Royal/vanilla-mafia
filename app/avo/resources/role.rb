class Avo::Resources::Role < Avo::BaseResource
  def fields
    field :code, as: :id
    field :name, as: :text
    field :ratings, as: :has_many
  end
end
