module ApplicationHelper
  include Pagy::Frontend

  def available_seasons
    Game.available_seasons
  end
end
