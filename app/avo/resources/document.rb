class Avo::Resources::Document < Avo::BaseResource
  self.title = :title
  self.default_view_type = :table
  self.find_record_method = -> {
    query.find_by(slug: id) || query.find(id)
  }

  self.index_query = -> {
    query.ordered
  }

  def fields
    field :id, as: :id
    field :title, as: :text, required: true
    field :slug, as: :text, help: I18n.t("avo.document.slug_hint")
    field :position, as: :number
    field :published, as: :boolean
    field :body, as: :trix
  end
end
