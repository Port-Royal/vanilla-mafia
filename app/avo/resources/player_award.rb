class Avo::Resources::PlayerAward < Avo::BaseResource
  self.title = :id
  self.default_view_type = :table

  def fields
    field :id, as: :id
    field :player, as: :belongs_to, searchable: true, sortable: true
    field :award, as: :belongs_to, searchable: true, sortable: true
    field :season, as: :number, required: true, sortable: true
    field :position, as: :number, sortable: true
  end
end
