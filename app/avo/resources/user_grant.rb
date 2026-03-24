class Avo::Resources::UserGrant < Avo::BaseResource
  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    field :grant, as: :belongs_to
  end
end
