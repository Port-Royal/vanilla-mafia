# Navigation state for the site shell.
module NavigationHelper
  NavItem = Data.define(:key, :label, :path)

  # Narrow reading: an item is active only on its own page; News also on its articles.
  # Like current_page?, only GET and HEAD requests mark an item active.
  def nav_active?(path)
    return false unless request.get? || request.head?
    return true if current_page?(path)

    path == news_index_path && request.path.start_with?("#{news_index_path}/")
  end

  # Role-gated links for the signed-in menus, each shown only to the roles that may open it.
  def role_nav_items(user)
    items = []
    items << nav_item(:podcast, podcast_episodes_path) if user.subscriber? || user.admin?
    items << nav_item(:protocols, judge_protocols_path) if user.can_manage_protocols?
    items << nav_item(:breakdowns, judge_breakdowns_path) if user.can_manage_protocols? && FeatureToggle.enabled?("game_breakdown")
    items << nav_item(:help, help_index_path) if user.can_view_help?
    items << nav_item(:manage_news, admin_news_index_path) if user.can_manage_news?
    items.concat(admin_nav_items) if user.admin?
    items << nav_item(:notification_settings, edit_notification_settings_path) if user.can_manage_news?
    items
  end

  private

  def admin_nav_items
    [ nav_item(:telegram, admin_telegram_settings_path), nav_item(:admin, avo.root_path) ]
  end

  def nav_item(key, path)
    NavItem.new(key:, label: t("nav.#{key}"), path:)
  end
end
