class Avo::Resources::UserGrant < Avo::BaseResource
  self.visible_on_sidebar = false

  def fields
    field :id, as: :id
    field :user, as: :belongs_to, searchable: true
    field :grant, as: :belongs_to, searchable: true
  end
end
