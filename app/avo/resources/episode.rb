class Avo::Resources::Episode < Avo::BaseResource
  self.title = :title

  def self.navigation_label = "Podcast: Episodes"
  self.default_view_type = :table

  self.search = {
    query: -> { query.where("title ILIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :title, as: :text, required: true, sortable: true
    field :description, as: :textarea
    field :status, as: :select, enum: ::Episode.statuses
    field :published_at, as: :date_time, sortable: true
    field :duration_seconds, as: :number
    field :audio, as: :file
  end
end
