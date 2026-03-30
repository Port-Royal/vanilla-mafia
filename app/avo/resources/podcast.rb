class Avo::Resources::Podcast < Avo::BaseResource
  self.title = :title

  def self.navigation_label = "Podcast: Settings"
  self.default_view_type = :table

  def fields
    field :id, as: :id
    field :title, as: :text, required: true
    field :author, as: :text, required: true
    field :description, as: :textarea, required: true
    field :language, as: :text, required: true
    field :category, as: :text
    field :cover, as: :file
  end
end
