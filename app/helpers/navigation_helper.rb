# Navigation state for the redesigned shell.
module NavigationHelper
  # Narrow reading: an item is active only on its own page; News also on its articles.
  def nav_active?(path)
    return true if current_page?(path)

    path == news_index_path && request.path.start_with?("#{news_index_path}/")
  end
end
