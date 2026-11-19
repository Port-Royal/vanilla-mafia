# Navigation state for the redesigned shell.
module NavigationHelper
  # Narrow reading: an item is active only on its own page; News also on its articles.
  # Like current_page?, only GET and HEAD requests mark an item active.
  def nav_active?(path)
    return false unless request.get? || request.head?
    return true if current_page?(path)

    path == news_index_path && request.path.start_with?("#{news_index_path}/")
  end
end
