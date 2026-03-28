class Avo::Resources::Award < Avo::BaseResource
  self.title = :title
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("title ILIKE ?", "%#{params[:q]}%") }
  }

  self.index_query = -> {
    query.order(staff: :asc, position: :asc, id: :asc)
  }

  def fields
    field :id, as: :id
    field :title, as: :text, required: true, sortable: true
    field :description, as: :textarea
    field :staff, as: :boolean, sortable: true
    field :position, as: :number, sortable: true
    field :icon, as: :file, is_image: true
    field :player_awards, as: :has_many
  end
end
