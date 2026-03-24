class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :email, as: :text
    field :role, as: :select, enum: ::User.roles, readonly: true, help: "Legacy field — use grants below"
    field :player, as: :belongs_to
    field :user_grants, as: :has_many
  end
end
