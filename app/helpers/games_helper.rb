module GamesHelper
  OVERLAY_ROLE_BADGE_CODES = %w[sheriff don mafia peace].freeze
  OVERLAY_ELIMINATED_STATUSES = %i[killed_by_mafia voted_out banned].freeze
  OVERLAY_STATUS_ICONS_DIR = Rails.root.join("app/assets/images/overlay/status")
  # Best move cells: black when the named player is mafia (a hit), red when a civilian (a miss).
  OVERLAY_BEST_MOVE_COLOURS = { "mafia" => "black", "don" => "black", "peace" => "red", "sheriff" => "red" }.freeze
  OVERLAY_BEST_MOVE_NEUTRAL = "neutral".freeze

  def overlay_player_status(participation)
    return nil unless participation

    participation.status.to_sym
  end

  def overlay_role_badge(role_code)
    return unless OVERLAY_ROLE_BADGE_CODES.include?(role_code)

    t("games.overlay.role_badge.#{role_code}")
  end

  # The badge's colour comes from its role, so only roles with a badge are named.
  def overlay_role_badge_role(role_code)
    role_code if OVERLAY_ROLE_BADGE_CODES.include?(role_code)
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

  def overlay_seat_roles(participations_by_seat)
    participations_by_seat.slice(*GameBreakdown::SEAT_NUMBERS).transform_values(&:role_code).compact
  end

  def overlay_best_move_cells(participation, seat_roles)
    return [] unless participation

    participation.best_move_seats.to_a.map { |seat| [ seat, overlay_best_move_colour(seat_roles[seat]) ] }
  end

  # The colour of a seat's team, from a role the page may show. Mirrors seatColour in game_overlay_controller.js.
  def overlay_seat_colour(role_code)
    return "neutral" if role_code.nil?

    %w[don mafia].include?(role_code) ? "black" : "red"
  end

  OVERLAY_EMPTY_NIGHT = { text: "", colour: "none", mark: nil }.freeze
  OVERLAY_SKIPPED_NIGHT = { text: "×", colour: "empty", mark: nil }.freeze

  # Rows of the night block, one cell per night so the rows line up. Mirrors renderNight in
  # game_overlay_controller.js.
  def overlay_night_rows(shots, checks)
    nights = (shots + checks).map { |entry| entry[:night] }.max || 0
    {
      nights:,
      shots: overlay_night_row(shots, nights) { |shot| overlay_shot_cell(shot) },
      don: overlay_check_row(checks, "don", nights),
      sheriff: overlay_check_row(checks, "sheriff", nights)
    }
  end

  def overlay_canvas_class(game)
    class_names(
      "overlay-canvas text-white",
      "overlay-canvas--hide-roles" => !game.roles_public?,
      "overlay-canvas--hide-game-info" => game.hide_game_info,
      "overlay-canvas--hide-table-info" => game.hide_table_info
    )
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

  private

  def overlay_night_row(entries, nights)
    (1..nights).map do |night|
      entry = entries.find { |candidate| candidate[:night] == night }
      entry ? yield(entry) : OVERLAY_EMPTY_NIGHT
    end
  end

  def overlay_check_row(checks, kind, nights)
    return [] if checks.empty?

    overlay_night_row(checks.select { |check| check[:kind] == kind }, nights) { |check| overlay_check_cell(check) }
  end

  def overlay_shot_cell(shot)
    return OVERLAY_SKIPPED_NIGHT unless shot[:target_seat]

    { text: shot[:target_seat].to_s, colour: shot[:team] || "neutral", mark: nil }
  end

  def overlay_check_cell(check)
    return OVERLAY_SKIPPED_NIGHT unless check[:target_seat]

    text = check[:target_seat].to_s
    return { text:, colour: check[:result], mark: nil } if check[:kind] == "sheriff"
    return { text:, colour: "red", mark: "sheriff" } if check[:result] == "sheriff"

    { text:, colour: check[:team] || "neutral", mark: nil }
  end
end
