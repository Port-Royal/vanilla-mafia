module GamesHelper
  # Civilians get no badge: only the roles the stream needs to spot carry one.
  OVERLAY_ROLE_BADGE_CODES = %w[sheriff don mafia].freeze
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

  # A pip per foul and a mark per technical foul. Mirrors renderFouls in game_overlay_controller.js.
  def overlay_foul_pips(count)
    return [] unless count

    Array.new(count[:fouls], "foul") + Array.new(count[:tech], "tech")
  end

  # The colour of a seat's team, from a role the page may show. Mirrors seatColour in game_overlay_controller.js.
  def overlay_seat_colour(role_code)
    Game::TEAMS.fetch(role_code, "neutral")
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

  # The static OBS URL of the game's table; table 1 gets the short /overlay.
  def table_overlay_url_for(game)
    table = game.table_key
    table == Game::DEFAULT_TABLE ? overlay_url : table_overlay_url(number: table)
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

  MINUS_SIGN = "\u2212".freeze

  # A score without trailing zeros and with a real minus sign: 1, 0.4, −0.25. The dot stays in every locale.
  def format_score(value)
    return "" if value.nil?

    number = number_with_precision(value.abs, precision: 2, strip_insignificant_zeros: true, separator: ".")
    value.negative? ? "#{MINUS_SIGN}#{number}" : number
  end

  # The score columns folded into one line for phones: "1 − 0.2 + ЛХ 0.4", the empty parts left out.
  def score_parts(participation)
    parts = [ format_score(participation.plus || 0) ]
    parts << "#{MINUS_SIGN} #{format_score(participation.minus)}" if participation.minus.to_d.nonzero?
    if participation.best_move.to_d.nonzero?
      parts << "+ #{t("games.redesign.best_move_short")} #{format_score(participation.best_move)}"
    end
    parts.join(" ")
  end

  # A neighbour game's link text: its number, plus the table and the date when they differ from the current game's.
  def neighbour_game_label(neighbour, game)
    parts = [ "#{t("common.game")} #{neighbour.game_number}" ]
    if neighbour.table_number && neighbour.table_number != game.table_number
      parts << t("games.redesign.neighbour_table", number: neighbour.table_number)
    end
    parts << format_date(neighbour.played_on) if neighbour.played_on && neighbour.played_on != game.played_on
    parts.join(" · ")
  end

  # The ПУ and ЛХ abbreviations, spelled out on hover: the legend is hidden while a game is in progress.
  def first_shoot_abbr
    tag.abbr(t("games.redesign.first_shoot"), title: t("games.redesign.first_shoot_full"))
  end

  def best_move_abbr
    tag.abbr(t("games.redesign.best_move_short"), title: t("games.redesign.best_move_full"))
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
