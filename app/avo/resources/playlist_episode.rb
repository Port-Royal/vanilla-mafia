class Avo::Resources::PlaylistEpisode < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :playlist, as: :belongs_to
    field :episode, as: :belongs_to
    field :position, as: :number
  end
end
