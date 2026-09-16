module GameBreakdownsHelper
  BLACK_ROLES = %w[mafia don].freeze

  def breakdown_result_label(result)
    return t("game_breakdowns.results.unknown") if result.blank?

    t("game_breakdowns.results.#{result}")
  end

  def breakdown_seat_names(breakdown)
    breakdown.seats.to_h { |seat| [ seat.number, seat.name ] }
  end

  def breakdown_seat_label(seat_names, number)
    name = seat_names[number]
    return number.to_s if name.blank?

    "#{number} — #{name}"
  end

  # A new move starts as the speaker's own comment, dated to the last night the game has passed.
  def breakdown_move_defaults(context, state)
    { kind: "other", actor_seat: context.move_actor_seat, night_number: breakdown_passed_nights(state) }
  end

  def breakdown_passed_nights(state)
    nights = state.phase.position / 2
    nights if nights.positive?
  end

  def breakdown_move_summary(move, seat_names)
    [ t("game_breakdowns.move_kinds.#{move.kind}"), breakdown_move_details(move, seat_names) ].compact_blank.join(" · ")
  end

  def breakdown_move_details(move, seat_names)
    details = []
    details << breakdown_seat_label(seat_names, move.target_seat) if move.target_seat
    details << t("game_breakdowns.claimed_colors.#{move.claimed_color}") if move.claimed_color
    details << t("game_breakdowns.editor.night_number", number: move.night_number) if move.night_number
    details << move.best_move_seats.join(", ") if move.best_move_seats
    details << t("game_breakdowns.removal_reasons.#{move.removal_reason}") if move.removal_reason
    details << move.text if move.text.present?
    details.join(" · ")
  end

  # Candidate rounds tally by seat; lift rounds tally into the `for` and `against` buckets.
  def breakdown_tally_label(round, key, seat_names)
    return t("game_breakdowns.lift_choices.#{key}") if round.lift?

    breakdown_seat_label(seat_names, key)
  end

  def breakdown_vote_value(result, voter)
    vote = breakdown_vote_for(result, voter)
    return vote.candidate_seat if vote

    result.candidates.last
  end

  def breakdown_lift_value(result, voter)
    vote = breakdown_vote_for(result, voter)
    return if vote.nil?

    vote.for_lift.to_s
  end

  def breakdown_lift_options
    [ [ t("game_breakdowns.lift_choices.for"), "true" ], [ t("game_breakdowns.lift_choices.against"), "false" ] ]
  end

  # Outcome and killed seat are one choice: a kill is only ever valid with a seat, so offering them as two
  # fields would let the editor submit a kill with nothing killed, which the model rightly refuses.
  def breakdown_night_outcome_options(alive, seat_names)
    [ [ t("game_breakdowns.night_outcomes.miss"), "miss" ] ] +
      alive.map { |seat| [ t("game_breakdowns.night_outcomes.kill_seat", seat: breakdown_seat_label(seat_names, seat)), "kill:#{seat}" ] }
  end

  def breakdown_night_outcome_value(phase)
    return phase.night_outcome unless phase.kill?

    "kill:#{phase.killed_seat}"
  end

  def breakdown_role_seats(breakdown)
    breakdown.seats.group_by(&:role_code).transform_values { |seats| seats.map(&:number) }
  end

  # Every mafia member still in the game shoots; a dead one has nothing to record.
  def breakdown_shooter_seats(role_seats, alive)
    BLACK_ROLES.flat_map { |code| role_seats.fetch(code, []) }.select { |seat| alive.include?(seat) }.sort
  end

  # The don and the sheriff check while they are alive; the role says who they are.
  def breakdown_checker_seat(role_seats, role_code, alive)
    seat = role_seats.fetch(role_code, []).first
    seat if alive.include?(seat)
  end

  # The don learns sheriff / not sheriff, the sheriff learns red / black — both from the target's role.
  def breakdown_check_result(kind, target_role)
    return if target_role.blank?

    t("game_breakdowns.check_results.#{breakdown_check_result_key(kind, target_role)}")
  end

  def breakdown_check_result_key(kind, target_role)
    return target_role == "sheriff" ? "sheriff" : "not_sheriff" if kind == "don_check"

    BLACK_ROLES.include?(target_role) ? "black" : "red"
  end

  def breakdown_night_action(actions, kind, actor_seat)
    actions.find { |action| action.kind == kind && action.actor_seat == actor_seat }
  end

  def breakdown_check_target(action)
    return if action.nil?

    action.target_seat
  end

  def breakdown_shot_value(action)
    return if action.nil?

    action.target_seat.nil? ? SaveBreakdownNightService::NO_SHOT : action.target_seat.to_s
  end

  private

  def breakdown_vote_for(result, voter)
    result.round.votes.find { |vote| vote.voter_seat == voter }
  end
end
