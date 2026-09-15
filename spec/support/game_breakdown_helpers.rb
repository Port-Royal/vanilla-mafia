# Builders for game breakdown phases, speeches, moves and votes. Expects a `breakdown` in scope.
module GameBreakdownHelpers
  def night(position, killed: nil)
    create(:breakdown_phase, game_breakdown: breakdown, position: position,
                             night_outcome: killed ? "kill" : "miss", killed_seat: killed)
  end

  def day(position)
    create(:breakdown_phase, game_breakdown: breakdown, position: position)
  end

  def speech(phase, seat, kind: "regular", round: nil)
    create(:breakdown_speech, breakdown_phase: phase, speaker_seat: seat, kind: kind, breakdown_vote_round: round)
  end

  def nominate(phase, actor, target)
    create(:breakdown_move, :nomination, breakdown_speech: speech(phase, actor), actor_seat: actor, target_seat: target)
  end

  def remove(phase, *seats, kind: "regular")
    seats.each do |seat|
      create(:breakdown_move, :removal, breakdown_speech: speech(phase, seat, kind: kind), actor_seat: seat)
    end
  end

  # ballots: { [voter, ...] => candidate_seat } or { [voter, ...] => true/false } for lift rounds
  def vote(phase, kind, ballots = {})
    round = create(:breakdown_vote_round, breakdown_phase: phase, kind: kind, number: phase.vote_rounds.count + 1)
    ballots.each do |voters, choice|
      choice_attributes = kind == "lift" ? { for_lift: choice, candidate_seat: nil } : { candidate_seat: choice }
      Array(voters).each do |voter|
        create(:breakdown_vote, breakdown_vote_round: round, voter_seat: voter, **choice_attributes)
      end
    end
    round
  end

  def assign_roles(mafia:, don:, sheriff:)
    %w[peace sheriff mafia don].each { |code| Role.find_or_create_by!(code: code) { |role| role.name = code } }
    breakdown.seats.update_all(role_code: "peace")
    breakdown.seats.where(number: mafia).update_all(role_code: "mafia")
    breakdown.seats.where(number: don).update_all(role_code: "don")
    breakdown.seats.where(number: sheriff).update_all(role_code: "sheriff")
  end
end
