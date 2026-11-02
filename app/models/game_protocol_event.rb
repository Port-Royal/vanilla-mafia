class GameProtocolEvent < ApplicationRecord
  KINDS = %w[
    roles deal speaker suspect red team check_request nominate nomination_cancelled note vote round_closed
    round_cancelled vote_skipped leaving_closed shot miss_shot don_check sheriff_check night_closed best_move will foul tech
    sanction_cancelled player_left player_restored game_finished
  ].freeze
  PHASES = %w[deal day night].freeze
  DELETABLE_FROM_MIDDLE = %w[suspect red team check_request note will best_move].freeze
  LEFT_REASONS = %w[killed voted removed].freeze
  FINISHED_RESULTS = %w[peace_victory mafia_victory draw].freeze
  SEATS = (1..10)

  belongs_to :game

  validates :client_id, presence: true, uniqueness: { scope: :game_id }
  validates :action_id, presence: true
  validates :position, numericality: { only_integer: true }, uniqueness: { scope: :game_id }
  validates :kind, inclusion: { in: KINDS }
  validates :phase, inclusion: { in: PHASES }
  validates :day_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actor_seat, numericality: { only_integer: true, in: SEATS }, allow_nil: true
  validate :target_seats_are_seats
  validate :metadata_is_a_hash
  validate :outcome_is_complete

  # The last action can always be undone. Deleting from the middle replays the journal,
  # so only actions that later events do not depend on may go.
  def self.removable_group?(events)
    last_position = events.first.game.game_protocol_events.maximum(:position)
    events.any? { |event| event.position == last_position } || events.all?(&:deletable_from_middle?)
  end

  def deletable_from_middle?
    return true if DELETABLE_FROM_MIDDLE.include?(kind)

    kind == "nominate" && !game.game_protocol_events.exists?(kind: "vote", day_number:)
  end

  private

  def target_seats_are_seats
    return if target_seats.is_a?(Array) && target_seats.all? { |seat| seat.is_a?(Integer) && SEATS.cover?(seat) }

    errors.add(:target_seats, :invalid)
  end

  def metadata_is_a_hash
    errors.add(:metadata, :invalid) unless metadata.is_a?(Hash)
  end

  def outcome_is_complete
    return unless metadata.is_a?(Hash)

    case kind
    when "roles"
      errors.add(:metadata, :invalid) unless metadata["roles"].is_a?(Hash)
    when "player_left"
      errors.add(:metadata, :invalid) unless LEFT_REASONS.include?(metadata["reason"])
      errors.add(:target_seats, :blank) if target_seats.blank?
    when "player_restored"
      errors.add(:target_seats, :blank) if target_seats.blank?
    when "game_finished"
      errors.add(:metadata, :invalid) unless FINISHED_RESULTS.include?(metadata["result"])
    end
  end
end
