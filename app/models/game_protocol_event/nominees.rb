# Who stands for the vote right now, replayed from the journal. The list keeps nomination order,
# survives the vote and the leaving speeches, and is gone once the night begins.
class GameProtocolEvent::Nominees
  NIGHT_STARTERS = %w[vote_skipped round_cancelled].freeze

  def self.call(events)
    new.replay(events)
  end

  def initialize
    @seats = []
    @voting = false
    @departing = 0
  end

  def replay(events)
    events.each { |event| apply(event) }
    @seats
  end

  private

  def apply(event)
    return clear if event.phase == "night" || NIGHT_STARTERS.include?(event.kind)

    case event.kind
    when "nominate" then @seats += event.target_seats
    when "nomination_cancelled" then @seats -= event.target_seats
    when "speaker" then @voting ||= event.actor_seat.nil?
    when "round_closed" then close_round(event.metadata["outcome"])
    when "player_left" then player_left(event)
    when "leaving_closed" then leaving_closed
    end
  end

  def close_round(outcome)
    clear if outcome == "none"
  end

  def player_left(event)
    case event.metadata["reason"]
    when "voted" then @departing += 1
    when "removed" then @seats -= event.target_seats unless @voting
    end
  end

  # The vote's last leaving speech hands over to the night. A morning speech has nobody departing.
  def leaving_closed
    return if @departing.zero?

    @departing -= 1
    clear if @departing.zero?
  end

  def clear
    @seats = []
    @voting = false
    @departing = 0
  end
end
