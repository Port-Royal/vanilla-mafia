class Avo::Resources::Competition < Avo::BaseResource
  self.title = :name

  def fields
    field :id, as: :id
    field :name, as: :text
    field :kind, as: :select, enum: ::Competition.kinds
    field :parent, as: :belongs_to, required: false
    field :games, as: :has_many
  end
end
