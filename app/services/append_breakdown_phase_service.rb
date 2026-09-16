# Creates the phase the timeline expects next.
# A night is empty; a day is pre-filled with the farewell speech of the night-killed seat
# (when there is one) followed by regular speeches of the alive seats in speech order.
class AppendBreakdownPhaseService
  def self.call(breakdown:)
    new(breakdown).call
  end

  def initialize(breakdown)
    @breakdown = breakdown
  end

  def call
    step = GameBreakdown::Timeline.new(@breakdown).next_phase
    return if step.nil?

    ActiveRecord::Base.transaction do
      phase = @breakdown.phases.create!(position: step.position)
      create_speeches(phase, step)
      phase
    end
  end

  private

  # A night step carries neither a farewell seat nor a speech order, so it stays empty.
  def create_speeches(phase, step)
    speakers = Array(step.farewell_seat).map { |seat| [ seat, "farewell" ] } + step.speech_order.map { |seat| [ seat, "regular" ] }

    speakers.each_with_index do |(seat, kind), position|
      phase.speeches.create!(speaker_seat: seat, kind: kind, position: position)
    end
  end
end
