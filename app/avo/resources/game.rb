class Avo::Resources::Game < Avo::BaseResource
  self.title = :full_name
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("name ILIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :season, as: :number, required: true, sortable: true
    field :series, as: :number, required: true, sortable: true
    field :game_number, as: :number, required: true, sortable: true
    field :played_on, as: :date, sortable: true
    field :name, as: :text
    field :result, as: :text
    field :ratings, as: :has_many
  end
end
