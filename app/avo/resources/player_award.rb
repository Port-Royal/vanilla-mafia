class Avo::Resources::PlayerAward < Avo::BaseResource
  self.title = :id
  self.visible_on_sidebar = false
  self.default_view_type = :table

  def fields
    field :id, as: :id
    field :player, as: :belongs_to, searchable: true, sortable: true
    field :award, as: :belongs_to, searchable: true, sortable: true
    field :competition, as: :belongs_to
    field :position, as: :number, sortable: true
  end
end
