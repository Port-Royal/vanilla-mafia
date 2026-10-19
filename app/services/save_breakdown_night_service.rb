# Replaces the recorded internals of one night from the editor's night form.
# A blank choice means nothing was recorded and removes the row; NO_SHOT records a mafia member who
# did not shoot, which the schema stores as a shot with no target; TACTICAL_MISS records a deliberate,
# demonstrative miss — also a shot with no target, flagged as tactical.
# Only open roles mode may hold these rows at all — BreakdownNightAction enforces that, so a day phase
# or a closed-roles breakdown simply persists nothing.
class SaveBreakdownNightService
  NO_SHOT = "none".freeze
  TACTICAL_MISS = "tactical_miss".freeze
  CHECK_KINDS = BreakdownNightAction::CHECKER_ROLES.keys.freeze

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
    drop_shots unless @phase.miss?
  end

  private

  def save_shot(actor_seat, choice)
    action = @phase.night_actions.find_or_initialize_by(kind: "mafia_shot", actor_seat: actor_seat)
    return action.destroy if choice.blank?

    action.update(shot_attributes(choice))
  end

  # Not shooting and a tactical miss are both shots with no target; every choice sets the flag, so a correction clears it.
  def shot_attributes(choice)
    case choice
    when NO_SHOT then { target_seat: nil, tactical_miss: false }
    when TACTICAL_MISS then { target_seat: nil, tactical_miss: true }
    else { target_seat: choice, tactical_miss: false }
    end
  end

  # Shots are only recorded on a miss — a kill says who the mafia hit — so any left from an earlier
  # miss would contradict the outcome once it changes.
  def drop_shots
    @phase.night_actions.where(kind: "mafia_shot").destroy_all
  end

  # A check has no actor: the don and the sheriff are known from their roles.
  def save_check(kind, target_seat)
    return unless CHECK_KINDS.include?(kind)

    action = @phase.night_actions.find_or_initialize_by(kind: kind)
    return action.destroy if target_seat.blank?

    action.update(target_seat: target_seat)
  end
end
