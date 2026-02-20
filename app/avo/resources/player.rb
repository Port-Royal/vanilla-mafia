class Avo::Resources::Player < Avo::BaseResource
  self.title = :name
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("name ILIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, required: true, sortable: true
    field :position, as: :number, sortable: true
    field :comment, as: :textarea
    field :photo, as: :file, is_image: true
    field :ratings, as: :has_many
    field :player_awards, as: :has_many
  end
end
