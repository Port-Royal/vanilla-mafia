# A non-blocking rule warning attached to a breakdown record: phase, speech, move, vote round, vote, night action or the breakdown.
class GameBreakdown::Timeline::Warning < Data.define(:code, :record, :rule, :details)
  CODES = %i[
    eliminated_speaker eliminated_actor eliminated_target eliminated_checker
    unexpected_farewell unexpected_justification repeated_nomination check_claim_night_out_of_range best_move_without_right
    non_candidate_vote zero_round_single_nominee_voting voting_after_removal lift_forbidden unexpected_vote_round
    missing_mafia missing_don missing_sheriff
  ].freeze

  def self.for_seat(code, record, seat, rule: nil)
    new(code: code, record: record, rule: rule, details: { seat: seat })
  end

  def initialize(code:, record:, rule: nil, details: {})
    raise ArgumentError, "unknown warning code: #{code}" unless CODES.include?(code)

    super
  end

  def message
    I18n.t("game_breakdowns.warnings.#{code}", **details)
  end
end
