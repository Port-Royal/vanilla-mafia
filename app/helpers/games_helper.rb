module GamesHelper
  OVERLAY_ROLE_BADGE_CODES = %w[sheriff don mafia].freeze
  OVERLAY_ELIMINATED_STATUSES = %i[killed_by_mafia voted_out banned].freeze
  OVERLAY_STATUS_ICONS_DIR = Rails.root.join("app/assets/images/overlay/status")

  def overlay_custom_style(config)
    parts = []
    parts << "font-size: #{config[:font_size]}px" if config[:font_size]
    parts << "color: ##{config[:color]}" if config[:color]
    parts.join("; ")
  end

  def overlay_player_status(participation)
    return nil unless participation

    participation.status.to_sym
  end

  def overlay_role_badge(role_code)
    return unless OVERLAY_ROLE_BADGE_CODES.include?(role_code)

    t("games.overlay.role_badge.#{role_code}")
  end

  def overlay_eliminated?(status)
    OVERLAY_ELIMINATED_STATUSES.include?(status)
  end

  def overlay_status_icon(status)
    return unless overlay_eliminated?(status)

    svg = Nokogiri::XML(OVERLAY_STATUS_ICONS_DIR.join("#{status}.svg")).root
    svg["class"] = "h-full w-full drop-shadow"
    svg["data-status"] = status
    svg["aria-hidden"] = "true"
    svg.to_xml.html_safe # rubocop:disable Rails/OutputSafety -- our own asset files, not user input
  end

  def overlay_table_label(game)
    return if game.table_number.blank?

    t("games.overlay.table", number: game.table_number)
  end

  # The total games count arrives with a protocol field of its own; until then only the number is shown.
  def overlay_game_label(game)
    t("games.overlay.game", number: game.game_number)
  end

  def overlay_judge_label(game)
    return if game.judge.blank?

    t("games.overlay.judge", name: game.judge)
  end
end
