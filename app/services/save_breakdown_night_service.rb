# Replaces the recorded internals of one night from the editor's night form.
# A blank choice means nothing was recorded and removes the row; NO_SHOT records a mafia member who
# deliberately did not shoot, which the schema stores as a shot with no target.
# Only open roles mode may hold these rows at all — BreakdownNightAction enforces that, so a day phase
# or a closed-roles breakdown simply persists nothing.
class SaveBreakdownNightService
  NO_SHOT = "none".freeze
  CHECK_KINDS = %w[don_check sheriff_check].freeze

  def self.call(phase:, shots:, checks:)
    new(phase, shots, checks).call
  end

  def initialize(phase, shots, checks)
    @phase = phase
    @shots = shots
    @checks = checks
  end

  def call
    @shots.each { |actor_seat, choice| save_shot(actor_seat, choice) }
    @checks.each { |kind, target_seat| save_check(kind, target_seat) }
  end

  private

  def save_shot(actor_seat, choice)
    action = @phase.night_actions.find_or_initialize_by(kind: "mafia_shot", actor_seat: actor_seat)
    return action.destroy if choice.blank?

    action.update(target_seat: shot_target(choice))
  end

  # A mafia member who did not shoot is recorded as a shot with no target.
  def shot_target(choice)
    return if choice == NO_SHOT

    choice
  end

  # A check has no actor: the don and the sheriff are known from their roles.
  def save_check(kind, target_seat)
    return unless CHECK_KINDS.include?(kind)

    action = @phase.night_actions.find_or_initialize_by(kind: kind)
    return action.destroy if target_seat.blank?

    action.update(target_seat: target_seat)
  end
end
