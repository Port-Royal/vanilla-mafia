# Best move: the first-killed player names 1–3 distinct seats as mafia.
# Pass `excluding: :attribute` to also reject a list naming the seat held in that attribute.
class BestMoveSeatsValidator < ActiveModel::EachValidator
  SEATS_COUNT = (1..3)

  def validate_each(record, attribute, value)
    return if value.nil?
    return record.errors.add(attribute, :invalid) unless valid_shape?(value)

    record.errors.add(attribute, :own_seat) if names_own_seat?(record, value)
  end

  private

  def valid_shape?(seats)
    seats.is_a?(Array) &&
      SEATS_COUNT.cover?(seats.size) &&
      seats.uniq.size == seats.size &&
      seats.all? { |seat| seat.is_a?(Integer) && GameBreakdown::SEAT_NUMBERS.cover?(seat) }
  end

  def names_own_seat?(record, seats)
    own_seat_attribute = options[:excluding]
    own_seat_attribute && seats.include?(record.public_send(own_seat_attribute))
  end
end
