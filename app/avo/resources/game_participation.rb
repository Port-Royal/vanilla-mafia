class Avo::Resources::GameParticipation < Avo::BaseResource
  self.title = :id
  self.default_view_type = :table

  def fields
    field :id, as: :id
    field :game, as: :belongs_to
    field :player, as: :belongs_to, searchable: true
    field :role, as: :belongs_to
    field :plus, as: :number
    field :minus, as: :number
    field :best_move, as: :number
    field :win, as: :boolean
    field :first_shoot, as: :boolean
  end
end
