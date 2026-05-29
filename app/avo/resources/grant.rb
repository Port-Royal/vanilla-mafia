class Avo::Resources::Grant < Avo::BaseResource
  self.title = :code

  self.search = {
    query: -> { query.where("LOWER(code) LIKE LOWER(?)", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :code, as: :text, readonly: true
    field :user_grants, as: :has_many
  end
end
