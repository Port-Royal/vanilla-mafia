class Avo::Resources::User < Avo::BaseResource
  self.title = :display_name
  self.includes = [ :player ]

  self.search = {
    query: -> { query.left_joins(:player).where("users.email ILIKE :q OR players.name ILIKE :q", q: "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :email, as: :text
    field :player, as: :belongs_to
    field :user_grants, as: :has_many
  end

  def actions
    action Avo::Actions::ResetPassword
  end
end
