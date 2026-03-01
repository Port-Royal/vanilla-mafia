class Avo::Resources::PlayerClaim < Avo::BaseResource
  self.title = :id
  self.default_view_type = :table

  def fields
    field :id, as: :id
    field :user, as: :belongs_to, searchable: true
    field :player, as: :belongs_to, searchable: true
    field :status, as: :badge, map: { pending: :warning, approved: :success, rejected: :danger }
    field :dispute, as: :boolean
    field :evidence, as: :textarea, visible: ->(resource:, **) { resource.record.dispute? }
    field :rejection_reason, as: :text
    field :reviewed_by, as: :belongs_to, name: "Reviewed by"
    field :reviewed_at, as: :date_time
    field :created_at, as: :date_time, sortable: true
    field :updated_at, as: :date_time, sortable: true
  end

  def actions
    action Avo::Actions::ApproveClaim
    action Avo::Actions::RejectClaim
  end
end
