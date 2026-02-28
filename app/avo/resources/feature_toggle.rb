class Avo::Resources::FeatureToggle < Avo::BaseResource
  self.title = :key
  self.default_view_type = :table

  self.search = {
    query: -> {
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)
      query.where("key LIKE ?", "%#{sanitized_query}%")
    }
  }

  def fields
    field :id, as: :id
    field :key, as: :select, options: -> { ::FeatureToggle::KEYS.map { |k| [k, k] } }
    field :enabled, as: :boolean
    field :description, as: :textarea
    field :updated_at, as: :date_time, sortable: true
  end
end
