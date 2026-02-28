class Avo::Resources::FeatureToggle < Avo::BaseResource
  self.title = :key
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("key LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :key, as: :text
    field :enabled, as: :boolean
    field :description, as: :textarea
    field :updated_at, as: :date_time, sortable: true
  end
end
