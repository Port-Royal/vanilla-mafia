module ApplicationHelper
  include Pagy::Frontend

  def featured_competitions
    @featured_competitions ||= Competition.featured.ordered
  end
end
