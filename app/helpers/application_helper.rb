module ApplicationHelper
  def available_seasons
    Game.available_seasons
  end
end
