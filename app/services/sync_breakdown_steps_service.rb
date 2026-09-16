# Materialises the blocks the timeline expects next, for every phase of a breakdown.
# Runs after each day edit: nominations open a main round, a tie adds justification speeches and a revote
# (or a lift when the revote tied among all of its candidates), and an elimination adds farewell speeches.
# Nothing is ever deleted here — a block that a correction made obsolete stays and is flagged as a warning.
class SyncBreakdownStepsService
  def self.call(breakdown:)
    new(breakdown).call
  end

  def initialize(breakdown)
    @breakdown = breakdown
  end

  def call
    ActiveRecord::Base.transaction do
      GameBreakdown::Timeline.new(@breakdown).phases.each do |state|
        state.expected_steps.each { |step| apply(state.phase, step) }
      end
    end
  end

  private

  def apply(phase, step)
    case step.kind
    when :main_round then create_round(phase, "main")
    when :revote_round then create_justifications(phase, step.seats, create_round(phase, "revote"))
    when :lift_round then create_round(phase, "lift")
    when :farewell_speeches then create_speeches(phase, step.seats, "farewell")
    end
  end

  def create_round(phase, kind)
    phase.vote_rounds.create!(kind: kind, number: phase.vote_rounds.size + 1)
  end

  def create_justifications(phase, seats, round)
    create_speeches(phase, seats, "justification", round: round)
  end

  def create_speeches(phase, seats, kind, round: nil)
    seats.each do |seat|
      phase.speeches.create!(speaker_seat: seat, kind: kind, position: next_speech_position(phase), breakdown_vote_round: round)
    end
  end

  def next_speech_position(phase)
    positions = phase.speeches.map(&:position)
    positions.empty? ? 0 : positions.max + 1
  end
end
