class Avo::Resources::Game < Avo::BaseResource
  self.title = :full_name
  self.default_view_type = :table
  self.find_record_method = -> {
    query.find_by(slug: id) || query.find(id)
  }

  self.search = {
    query: -> { query.where("name ILIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :competition, as: :belongs_to, required: true
    field :game_number, as: :number, required: true, sortable: true
    field :played_on, as: :date, sortable: true
    field :name, as: :text
    field :result, as: :select, enum: ::Game.results
    field :judge, as: :text
    field :game_participations, as: :has_many
  end

  def actions
    action Avo::Actions::EditProtocol
  end
end
