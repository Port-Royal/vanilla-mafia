class Avo::Resources::GameBreakdown < Avo::BaseResource
  self.title = :title

  def self.navigation_label = "Game breakdowns"
  self.default_view_type = :table

  self.search = {
    query: -> {
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)
      query.where("LOWER(title) LIKE LOWER(?)", "%#{sanitized_query}%")
    }
  }

  # Metadata only: seats, phases, speeches, votes and moves are edited in the judge editor,
  # where the timeline keeps them consistent with one another.
  def fields
    field :id, as: :id
    field :title, as: :text, required: true
    field :played_on, as: :date, sortable: true
    field :source, as: :text
    field :video_url, as: :text
    field :judge_name, as: :text
    field :roles_mode, as: :select, enum: ::GameBreakdown.roles_modes
    field :manual_result, as: :select, enum: ::GameBreakdown.manual_results, include_blank: true
    field :conclusion, as: :textarea
    field :author, as: :belongs_to
    field :game, as: :belongs_to
    field :created_at, as: :date_time, sortable: true
  end
end
