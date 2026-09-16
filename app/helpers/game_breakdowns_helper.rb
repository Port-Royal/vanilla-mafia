module GameBreakdownsHelper
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

  private

  def breakdown_vote_for(result, voter)
    result.round.votes.find { |vote| vote.voter_seat == voter }
  end
end
