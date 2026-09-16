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
end
