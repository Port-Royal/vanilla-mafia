# Narrows the read-only breakdown view down to one player: their own speeches and moves, moves and votes involving them
# and night events aimed at or made by them. `.for` falls back to Everything, which leaves the whole game in place, so the
# views ask the same questions whether a player is selected or not.
module GameBreakdown::SeatFilter
  def self.for(breakdown, seat_param)
    seat = Integer(seat_param.to_s, 10, exception: false)
    return Everything.new unless GameBreakdown::SEAT_NUMBERS.include?(seat)

    Seat.new(seat, breakdown.seats.to_h { |row| [ row.role_code, row.number ] })
  end

  class Everything
    def seat = nil
    def phase?(_state) = true
    def speeches(speeches) = speeches.to_a
    def speech_moves(speech) = speech.moves.to_a
    def rounds(results) = results
    def tally(result) = result.tally
    def round_moves(round) = round.moves.to_a
    def night_outcome?(_phase) = true
    def night_actions(phase) = phase.night_actions.to_a
  end

  class Seat
    attr_reader :seat

    def initialize(seat, checkers)
      @seat = seat
      @checkers = checkers
    end

    def phase?(state)
      return night_outcome?(state.phase) || night_actions(state.phase).any? if state.phase.night?

      speeches(state.opening_speeches + state.closing_speeches).any? || rounds(state.vote_rounds).any?
    end

    def speeches(speeches)
      speeches.select { |speech| speech.speaker_seat == seat || speech.moves.any? { |move| move?(move) } }
    end

    # The player's own speech is shown whole; in anyone else's only the moves involving them.
    def speech_moves(speech)
      return speech.moves.to_a if speech.speaker_seat == seat

      speech.moves.select { |move| move?(move) }
    end

    def rounds(results)
      results.select do |result|
        tally(result).any? || round_moves(result.round).any? || speeches(result.round.justification_speeches).any?
      end
    end

    # Rows with the player's own vote and, when they are a candidate, the votes cast for them; a lift of theirs in full.
    def tally(result)
      return result.tally if result.round.lift? && result.candidates.include?(seat)

      result.tally.select { |key, voters| key == seat || voters.include?(seat) }
    end

    def round_moves(round)
      round.moves.select { |move| move?(move) }
    end

    def night_outcome?(phase)
      phase.killed_seat == seat
    end

    def night_actions(phase)
      phase.night_actions.select { |action| [ action.actor_seat, action.target_seat, checker(action) ].include?(seat) }
    end

    private

    def move?(move)
      move.actor_seat == seat || move.target_seat == seat || Array(move.best_move_seats).include?(seat)
    end

    def checker(action)
      @checkers[BreakdownNightAction::CHECKER_ROLES[action.kind]]
    end
  end
end
