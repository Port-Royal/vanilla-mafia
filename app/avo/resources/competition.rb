class Avo::Resources::Competition < Avo::BaseResource
  self.title = :name
  self.find_record_method = -> {
    query.find_by(slug: id) || query.find(id)
  }

  def fields
    field :id, as: :id
    field :name, as: :text, html: {
      edit: {
        input: {
          data: {
            controller: "slug-suggest",
            slug_suggest_target_value: "competition_slug",
            action: "input->slug-suggest#suggest"
          }
        }
      }
    }
    field :slug, as: :text, help: I18n.t("avo.competition.slug_hint")
    field :kind, as: :select, options: ::Competition::KINDS.values.to_h { |k| [ I18n.t("activerecord.attributes.competition.kinds.#{k}"), k ] }
    field :position, as: :number
    field :parent, as: :belongs_to, required: false
    field :started_on, as: :date
    field :ended_on, as: :date
    field :featured, as: :boolean
    field :children, as: :has_many
    field :games, as: :has_many
  end
end
