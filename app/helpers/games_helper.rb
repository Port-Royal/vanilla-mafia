module GamesHelper
  OVERLAY_ROLE_BADGE_CODES = %w[sheriff don mafia].freeze
  OVERLAY_ELIMINATED_STATUSES = %i[killed_by_mafia voted_out banned].freeze
  OVERLAY_STATUS_ICONS_DIR = Rails.root.join("app/assets/images/overlay/status")
  # Best move cells: black when the named player is mafia (a hit), red when a civilian (a miss).
  OVERLAY_BEST_MOVE_COLOURS = { "mafia" => "black", "don" => "black", "peace" => "red", "sheriff" => "red" }.freeze
  OVERLAY_BEST_MOVE_NEUTRAL = "neutral".freeze

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

  def overlay_best_move_colour(role_code)
    OVERLAY_BEST_MOVE_COLOURS.fetch(role_code, OVERLAY_BEST_MOVE_NEUTRAL)
  end

  # Hidden roles leave the map empty, so best move cells stay neutral on the page and in live updates.
  def overlay_seat_roles(participations_by_seat, hide_roles:)
    return {} if hide_roles

    participations_by_seat.sort.to_h.transform_values(&:role_code).compact
  end

  def overlay_best_move_cells(participation, seat_roles)
    return [] unless participation

    participation.best_move_seats.to_a.map { |seat| [ seat, overlay_best_move_colour(seat_roles[seat]) ] }
  end

  def overlay_table_label(game)
    return if game.table_number.blank?

    t("games.overlay.table", number: game.table_number)
  end

  def overlay_game_label(game)
    return t("games.overlay.game", number: game.game_number) if game.games_total.nil?

    t("games.overlay.game_of_total", number: game.game_number, total: game.games_total)
  end

  def overlay_judge_label(game)
    return if game.judge.blank?

    t("games.overlay.judge", name: game.judge)
  end
end
