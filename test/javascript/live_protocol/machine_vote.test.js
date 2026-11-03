import { describe, expect, it } from "vitest"
import { decide, replay, voteDecided } from "../../../app/javascript/live_protocol/machine.js"

const seats = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const allPlayers = seats.map((seat) => ({ seat, name: `Игрок ${seat}`, role_code: null }))

function game(startPlayers = allPlayers) {
  const events = []
  const api = {
    do(action) {
      const { events: produced, error } = decide(replay(startPlayers, events), action)
      expect(error).toBeNull()
      events.push(...produced)
      return api
    },
    try: (action) => decide(replay(startPlayers, events), action),
    get state() { return replay(startPlayers, events) },
    get kinds() { return events.map((event) => event.kind) },
    events,
    nominate(...candidates) {
      candidates.forEach((seat, index) => {
        api.do({ type: "set_speaker", seats: [startPlayers[index].seat] }).do({ type: "nominate", seats: [seat] })
      })
      return api
    },
    vote(...voters) { return api.do({ type: "vote_for", seats: voters }) },
    remove(seat) { return api.do({ type: "remove_player", seats: [seat] }) },
    newDay() {
      events.push({ kind: "night_closed", phase: "night", day_number: replay(startPlayers, events).day, actor_seat: null, target_seats: [], text: null, metadata: {} })
      return api
    }
  }
  const [a, b, c, d] = startPlayers.map((player) => player.seat)
  return api.do({ type: "assign_roles", seats: [a, b, c, d] }).do({ type: "finish_deal" })
}

const voting = (...candidates) => game().nominate(...candidates).do({ type: "start_vote" })
const dayOne = () => game().newDay()
const ninePlayers = allPlayers.slice(0, 9)

describe("entering the vote", () => {
  it("opens a round with the candidates in nomination order", () => {
    expect(voting(5, 3).state).toMatchObject({ stage: "vote", round: { type: "main", candidates: [5, 3], index: 0, votes: {} } })
  })

  it("goes to the night with no candidates", () => {
    const skipped = game().do({ type: "start_vote" })

    expect([skipped.state.stage, skipped.events.at(-1).kind, skipped.events.at(-1).metadata]).toEqual(["night_shot", "vote_skipped", { reason: "no_candidates" }])
  })

  it("goes to the night with one candidate in the zero circle", () => {
    const skipped = game().nominate(5).do({ type: "start_vote" })

    expect([skipped.state.stage, skipped.events.at(-1).metadata.reason]).toEqual(["night_shot", "single_candidate_zero"])
  })

  it("gives a single candidate on a later day every vote at once", () => {
    const single = dayOne().nominate(5).do({ type: "start_vote" })

    expect([single.kinds.slice(-4), single.events.at(-3).metadata.auto, single.state.leaving])
      .toEqual([["speaker", "vote", "round_closed", "player_left"], seats, [5]])
  })

  it("writes only the move when the vote takes place", () => {
    const ready = game().nominate(5, 3)

    expect(ready.try({ type: "start_vote" }).events.map((event) => event.kind)).toEqual(["speaker"])
  })

  it("skips when the last speaker moves on with no candidates", () => {
    const circle = game()
    seats.slice(1).forEach(() => circle.do({ type: "next_speaker" }))

    expect(circle.do({ type: "next_speaker" }).kinds.slice(-2)).toEqual(["speaker", "vote_skipped"])
  })

  it("marks the skipped vote as part of the day", () => {
    expect(game().do({ type: "start_vote" }).events.at(-1)).toMatchObject({ phase: "day", day_number: 0 })
  })
})

describe("vote_for", () => {
  it("records the candidate and the voters", () => {
    expect(voting(5, 3, 4).try({ type: "vote_for", seats: [1, 2] }).events).toEqual([{
      kind: "vote", phase: "day", day_number: 0, actor_seat: null, target_seats: [5], text: null, metadata: { voters: [1, 2], auto: [] }
    }])
  })

  it("moves to the next candidate", () => {
    expect(voting(5, 3, 4).vote(1, 2).state.round).toMatchObject({ index: 1, votes: { 5: [1, 2] } })
  })

  it("accepts no voters", () => {
    expect(voting(5, 3, 4).vote().state.round.votes[5]).toEqual([])
  })

  it("accepts a vote_for with no seats at all", () => {
    expect(voting(5, 3, 4).do({ type: "vote_for" }).state.round.votes[5]).toEqual([])
  })

  it("drops a voter marked twice", () => {
    expect(voting(5, 3, 4).vote(1, 1).state.round.votes[5]).toEqual([1])
  })

  it("refuses a player who already voted", () => {
    expect(voting(5, 3, 4).vote(1).try({ type: "vote_for", seats: [1] })).toEqual({ events: [], error: "already_voted" })
  })

  it("refuses a player who left", () => {
    expect(voting(5, 3).try({ type: "vote_for", seats: [11] })).toEqual({ events: [], error: "not_alive" })
  })

  it("refuses outside the vote", () => {
    expect(game().try({ type: "vote_for", seats: [1] }).error).toBe("wrong_stage")
  })

  it("gives the last candidate everybody who has not voted without waiting for the judge", () => {
    const produced = voting(5, 3).try({ type: "vote_for", seats: [1, 2, 3, 4, 5, 6] }).events

    expect(produced.map((event) => event.kind)).toEqual(["vote", "vote", "round_closed", "player_left"])
    expect(produced[1]).toMatchObject({ target_seats: [3], metadata: { voters: [7, 8, 9, 10], auto: [7, 8, 9, 10] } })
  })

  it("does not wait on a candidate before the last one", () => {
    expect(voting(5, 3, 4).vote(1).state).toMatchObject({ stage: "vote", round: { index: 1 } })
  })

  it("counts only the players still at the table as automatic voters", () => {
    const fewer = voting(1, 2, 3).vote(3, 4, 5, 6, 7, 8).remove(10).vote(1)

    expect(fewer.events.filter((event) => event.kind === "vote").at(-1).metadata).toEqual({ voters: [2, 9], auto: [2, 9] })
  })

  it("closes on the earlier candidate when the later ones left the table", () => {
    const decided = voting(1, 2, 3).vote(3, 4, 5, 6, 7, 8).remove(3)

    expect(decided.events.filter((event) => event.kind === "vote").at(-1)).toMatchObject({ target_seats: [2], metadata: { auto: [1, 2, 9, 10] } })
  })

  it("refuses votes for a candidate who left the table", () => {
    const decided = voting(1, 2, 3, 4).vote(3, 4, 5, 6, 7, 8).remove(2)

    expect(decided.try({ type: "vote_for", seats: [9] }).error).toBe("not_alive")
  })

  it("records no votes for a candidate who left the table", () => {
    const decided = voting(1, 2, 3, 4).vote(3, 4, 5, 6, 7, 8).remove(2).vote()

    expect(decided.state.round.votes[2]).toEqual([])
  })
})

describe("the result", () => {
  it("removes a single leader", () => {
    const done = voting(5, 3).vote(1, 2, 3, 4, 5, 6)

    expect(done.events.slice(-2)).toEqual([
      { kind: "round_closed", phase: "day", day_number: 0, actor_seat: null, target_seats: [5], text: null, metadata: { outcome: "leave", leaders: [5] } },
      { kind: "player_left", phase: "day", day_number: 0, actor_seat: null, target_seats: [5], text: null, metadata: { reason: "voted" } }
    ])
  })

  it("moves to the leaving speech", () => {
    expect(voting(5, 3).vote(1, 2, 3, 4, 5, 6).state).toMatchObject({ stage: "leaving", leaving: [5], round: null })
  })

  it("marks the player as voted out", () => {
    expect(voting(5, 3).vote(1, 2, 3, 4, 5, 6).state.players[5]).toMatchObject({ out: true, outReason: "voted" })
  })

  it("closes at once when everybody alive has voted", () => {
    const nine = game(ninePlayers).nominate(1, 2, 3, 4, 5).do({ type: "start_vote" })
    nine.vote(1, 2, 3, 4, 5).vote(6, 7, 8, 9)

    expect(nine.state).toMatchObject({ stage: "leaving", leaving: [1] })
  })

  it("does not write votes for the candidates nobody was called for", () => {
    const nine = game(ninePlayers).nominate(1, 2, 3, 4, 5).do({ type: "start_vote" })
    nine.vote(1, 2, 3, 4, 5).vote(6, 7, 8, 9)

    expect(nine.kinds.filter((kind) => kind === "vote")).toHaveLength(2)
  })

  it("does not close on the last mark alone", () => {
    const nine = game(ninePlayers).nominate(1, 2, 3).do({ type: "start_vote" })

    expect(nine.vote(1, 2, 3, 4).state.stage).toBe("vote")
  })

  it("repeats a tie among the leaders", () => {
    const tied = voting(5, 3, 7).vote(1, 2, 3, 4, 6).vote(8, 9, 10, 5, 7)

    expect(tied.state).toMatchObject({ stage: "vote", round: { type: "repeat", candidates: [5, 3], index: 0, votes: {} } })
  })

  const threeWayTie = () => game(ninePlayers).newDay().nominate(1, 2, 3).do({ type: "start_vote" }).vote(1, 2, 3).vote(4, 5, 6)

  it("repeats when every candidate ties", () => {
    expect(threeWayTie().state.round).toMatchObject({ type: "repeat", candidates: [1, 2, 3] })
  })

  it("repeats again when a repeat ties with fewer candidates", () => {
    const tied = threeWayTie().vote(1, 2, 3, 4).vote(5, 6, 7, 8)

    expect(tied.state.round).toMatchObject({ type: "repeat", candidates: [1, 2] })
  })

  it("removes the single leader of a repeat", () => {
    const tied = voting(1, 2).vote(3, 4, 5, 6, 7)
    tied.vote(3, 4, 5, 6, 7, 8)

    expect(tied.state.leaving).toEqual([1])
  })
})

const liftAt = (...candidates) => {
  const round = dayOne().nominate(...candidates).do({ type: "start_vote" })
  const tie = () => {
    const voters = seats.slice()
    candidates.slice(0, -1).forEach(() => round.vote(...voters.splice(0, Math.floor(10 / candidates.length))))
  }
  tie()
  tie()
  return round
}

describe("the lift", () => {
  it("is called after a repeat ties with the same candidates", () => {
    expect(liftAt(1, 2).state.round).toMatchObject({ type: "lift", candidates: [1, 2] })
  })

  it("records the lift vote against every leader", () => {
    expect(liftAt(1, 2).try({ type: "vote_for", seats: [1, 2, 3] }).events[0]).toMatchObject({
      kind: "vote", target_seats: [1, 2], metadata: { voters: [1, 2, 3], auto: [], lift: true }
    })
  })

  it("removes every leader on a majority of the living", () => {
    const lifted = liftAt(1, 2).vote(1, 2, 3, 4, 5, 6)

    expect([lifted.state.stage, lifted.state.leaving, lifted.state.players[2].out]).toEqual(["leaving", [1, 2], true])
  })

  it("removes nobody at exactly half", () => {
    const lifted = liftAt(1, 2).vote(1, 2, 3, 4, 5)

    expect([lifted.state.stage, lifted.state.players[1].out]).toEqual(["night_shot", false])
  })

  it("writes the outcome", () => {
    expect(liftAt(1, 2).vote(1).events.at(-1)).toMatchObject({ kind: "round_closed", metadata: { outcome: "none", leaders: [1, 2] } })
  })

  it("does not give automatic votes", () => {
    expect(liftAt(1, 2).try({ type: "vote_for", seats: [] }).events[0].metadata.voters).toEqual([])
  })
})

describe("when the lift is not called", () => {
  const tieTwice = (round, shares) => {
    shares.slice(0, -1).forEach((share) => round.vote(...share))
    shares.slice(0, -1).forEach((share) => round.vote(...share))
    return round
  }

  it("removes nobody with 5 candidates in the zero circle", () => {
    const round = tieTwice(voting(1, 2, 3, 4, 5), [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]])

    expect([round.state.stage, round.events.at(-1).metadata]).toEqual(["night_shot", { outcome: "none", leaders: [1, 2, 3, 4, 5], reason: "five_or_ten_zero" }])
  })

  it("removes nobody with 3 candidates at 9 alive on any day", () => {
    const round = game(ninePlayers).newDay().nominate(1, 2, 3).do({ type: "start_vote" })
    tieTwice(round, [[1, 2, 3], [4, 5, 6], [7, 8, 9]])

    expect(round.events.at(-1).metadata.reason).toBe("three_of_nine")
  })

  const overHalf = () => {
    const six = allPlayers.slice(0, 6)
    return tieTwice(game(six).newDay().nominate(1, 2, 3, 4, 5, 6).do({ type: "start_vote" }), [[1], [2], [3], [4], [5], [6]])
  }

  it("removes nobody with more candidates than half of the living", () => {
    expect(overHalf().state).toMatchObject({ stage: "night_shot", round: null })
  })

  it("names that reason", () => {
    expect(overHalf().events.at(-1).metadata.reason).toBe("over_half")
  })

  it("still calls it with 5 candidates on a later day at exactly half", () => {
    const round = dayOne().nominate(1, 2, 3, 4, 5).do({ type: "start_vote" })
    tieTwice(round, [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]])

    expect(round.state.round.type).toBe("lift")
  })
})

describe("voteDecided", () => {
  const round = (votes, candidates = [1, 2, 3]) => ({ type: "main", candidates, index: 1, votes })
  const living = seats.slice(0, 9)

  it("is true when the rest cannot catch the leader", () => {
    expect(voteDecided(round({ 1: [1, 2, 3, 4, 5] }), living)).toBe(true)
  })

  it("is false when the rest could catch the leader", () => {
    expect(voteDecided(round({ 1: [1, 2, 3] }), living)).toBe(false)
  })

  it("is false when the rest could only tie", () => {
    expect(voteDecided(round({ 1: [1, 2, 3, 4] }), seats.slice(0, 8))).toBe(false)
  })

  it("finds the leader whichever candidate came first", () => {
    expect(voteDecided(round({ 1: [1], 2: [2, 3, 4, 5, 6] }), seats.slice(0, 8))).toBe(true)
  })

  it("is false with no votes", () => {
    expect(voteDecided(round({}), living)).toBe(false)
  })

  it("is false with two candidates tied and nobody left", () => {
    expect(voteDecided(round({ 1: [1, 2], 2: [3, 4] }), [1, 2, 3, 4])).toBe(false)
  })

  it("counts votes of departed players", () => {
    expect(voteDecided(round({ 1: [1, 2, 9] }), [1, 2, 3, 4])).toBe(true)
  })

  it("is false for a lift", () => {
    expect(voteDecided({ type: "lift", candidates: [1, 2], index: 0, votes: {} }, seats)).toBe(false)
  })

  it("compares against a candidate who already got votes", () => {
    expect(voteDecided(round({ 1: [1, 2, 3], 2: [4, 5, 6] }), [1, 2, 3, 4, 5, 6])).toBe(false)
  })
})

describe("sanctions", () => {
  it("records a foul", () => {
    expect(game().try({ type: "foul", seats: [3] }).events).toEqual([
      { kind: "foul", phase: "day", day_number: 0, actor_seat: null, target_seats: [3], text: null, metadata: {} }
    ])
  })

  it("counts fouls and technical fouls", () => {
    const fouled = game().do({ type: "foul", seats: [3] }).do({ type: "foul", seats: [3] }).do({ type: "tech", seats: [3] })

    expect(fouled.state.players[3]).toMatchObject({ fouls: 2, tech: 1, out: false })
  })

  it("applies to the speaker with no seat", () => {
    expect(game().try({ type: "foul" }).events[0].target_seats).toEqual([1])
  })

  it("applies to the speaker with empty seats", () => {
    expect(game().try({ type: "tech", seats: [] }).events[0].target_seats).toEqual([1])
  })

  it("needs a seat when nobody speaks", () => {
    expect(voting(5, 3).try({ type: "foul" })).toEqual({ events: [], error: "one_seat_required" })
  })

  it("refuses several seats", () => {
    expect(game().try({ type: "foul", seats: [1, 2] }).error).toBe("one_seat_required")
  })

  it("refuses a player who left", () => {
    expect(game().remove(3).try({ type: "foul", seats: [3] }).error).toBe("not_alive")
  })

  it.each(["foul", "tech", "remove_player", "cancel_foul", "cancel_tech"])("%s refuses during the roles and the deal", (type) => {
    const dealing = () => decide(replay(allPlayers, []), { type, seats: [1] })

    expect(dealing().error).toBe("wrong_stage")
  })

  it.each(["foul", "tech", "remove_player", "cancel_foul", "cancel_tech"])("%s refuses during the deal", (type) => {
    const assigned = decide(replay(allPlayers, []), { type: "assign_roles", seats: [1, 2, 3, 4] }).events

    expect(decide(replay(allPlayers, assigned), { type, seats: [1] }).error).toBe("wrong_stage")
  })

  it("removes on the 4th foul", () => {
    const fouled = game()
    ;[1, 2, 3, 4].forEach(() => fouled.do({ type: "foul", seats: [3] }))

    expect(fouled.state.players[3]).toMatchObject({ fouls: 4, out: true, outReason: "removed" })
  })

  it("does not remove on the 3rd foul", () => {
    const fouled = game()
    ;[1, 2, 3].forEach(() => fouled.do({ type: "foul", seats: [3] }))

    expect(fouled.state.players[3].out).toBe(false)
  })

  it("removes on the 2nd technical foul", () => {
    const fouled = game().do({ type: "tech", seats: [3] }).do({ type: "tech", seats: [3] })

    expect([fouled.state.players[3].out, fouled.kinds.slice(-2)]).toEqual([true, ["tech", "player_left"]])
  })

  it("does not remove on the 1st technical foul", () => {
    expect(game().do({ type: "tech", seats: [3] }).state.players[3].out).toBe(false)
  })

  it("names the sanction in the removal", () => {
    const fouled = game().do({ type: "tech", seats: [3] }).do({ type: "tech", seats: [3] })

    expect(fouled.events.at(-1).metadata).toEqual({ reason: "removed", sanction: "tech" })
  })
})

describe("cancelling a sanction", () => {
  const removedByFouls = () => {
    const fouled = game().nominate(3, 4)
    ;[1, 2, 3, 4].forEach(() => fouled.do({ type: "foul", seats: [3] }))
    return fouled
  }

  it("records the cancellation", () => {
    expect(game().do({ type: "foul", seats: [3] }).try({ type: "cancel_foul", seats: [3] }).events).toEqual([
      { kind: "sanction_cancelled", phase: "day", day_number: 0, actor_seat: null, target_seats: [3], text: null, metadata: { sanction: "foul" } }
    ])
  })

  it("needs a seat when nobody speaks", () => {
    expect(voting(5, 3).try({ type: "cancel_foul" })).toEqual({ events: [], error: "one_seat_required" })
  })

  it("applies to the speaker with no seat", () => {
    expect(game().do({ type: "foul" }).try({ type: "cancel_foul" }).events[0].target_seats).toEqual([1])
  })

  it("takes one foul off", () => {
    expect(game().do({ type: "foul", seats: [3] }).do({ type: "cancel_foul", seats: [3] }).state.players[3].fouls).toBe(0)
  })

  it("takes one technical foul off", () => {
    expect(game().do({ type: "tech", seats: [3] }).do({ type: "cancel_tech", seats: [3] }).state.players[3].tech).toBe(0)
  })

  it("does not touch the other kind", () => {
    const both = game().do({ type: "foul", seats: [3] }).do({ type: "tech", seats: [3] }).do({ type: "cancel_tech", seats: [3] })

    expect(both.state.players[3].fouls).toBe(1)
  })

  it("refuses when there is nothing to cancel", () => {
    expect(game().try({ type: "cancel_foul", seats: [3] })).toEqual({ events: [], error: "no_sanction" })
  })

  it("refuses technical fouls when there is only a foul", () => {
    expect(game().do({ type: "foul", seats: [3] }).try({ type: "cancel_tech", seats: [3] }).error).toBe("no_sanction")
  })

  it("refuses an empty seat", () => {
    expect(game(allPlayers.slice(0, 5)).try({ type: "cancel_foul", seats: [9] }).error).toBe("seat_empty")
  })

  it("brings back a player the sanction removed", () => {
    const back = removedByFouls().do({ type: "cancel_foul", seats: [3] })

    expect([back.state.players[3], back.kinds.slice(-2)]).toEqual([
      { name: "Игрок 3", role: "mafia", fouls: 3, tech: 0, out: false, outReason: null, removedBy: null },
      ["sanction_cancelled", "player_restored"]
    ])
  })

  it("writes the restored seat", () => {
    expect(removedByFouls().do({ type: "cancel_foul", seats: [3] }).events.at(-1)).toMatchObject({ kind: "player_restored", target_seats: [3] })
  })

  it("does not bring the candidacy back", () => {
    expect(removedByFouls().do({ type: "cancel_foul", seats: [3] }).state.candidates).toEqual([4])
  })

  it("does not bring the cancelled vote back", () => {
    const back = removedByFouls().do({ type: "cancel_foul", seats: [3] })

    expect(back.state.noVoteDay).toBe(0)
  })

  it("does not bring back a player removed by the judge directly", () => {
    const back = game().do({ type: "foul", seats: [3] }).remove(3).do({ type: "cancel_foul", seats: [3] })

    expect([back.state.players[3].out, back.kinds.at(-1)]).toEqual([true, "sanction_cancelled"])
  })

  it("does not bring back through the other kind of sanction", () => {
    const fouled = game().do({ type: "foul", seats: [3] }).do({ type: "tech", seats: [3] }).do({ type: "tech", seats: [3] })

    expect(fouled.do({ type: "cancel_foul", seats: [3] }).state.players[3].out).toBe(true)
  })

  it("does not bring back a player voted out", () => {
    const done = voting(5, 3).vote(1, 2, 3, 4, 5, 6)

    expect(done.do({ type: "foul", seats: [1] }).do({ type: "cancel_foul", seats: [1] }).state.players[5].out).toBe(true)
  })
})

describe("removal and the vote", () => {
  it("cancels today's vote during the speeches", () => {
    expect(game().remove(5).state.noVoteDay).toBe(0)
  })

  it("does not cancel anything when a player is voted out", () => {
    expect(voting(5, 3).vote(1, 2, 3, 4, 5, 6).state.noVoteDay).toBeNull()
  })

  it("empties the leaving list on the new day", () => {
    expect(voting(5, 3).vote(1, 2, 3, 4, 5, 6).newDay().state.leaving).toEqual([])
  })

  it("lets the speeches go on", () => {
    expect(game().remove(5).state).toMatchObject({ stage: "speech", speaker: 1 })
  })

  it("sends the day to the night when the speeches end", () => {
    const skipped = game().nominate(3, 4).remove(5).do({ type: "start_vote" })

    expect([skipped.state.stage, skipped.events.at(-1).metadata.reason]).toEqual(["night_shot", "cancelled"])
  })

  it("adds nothing on a second removal", () => {
    expect(game().remove(5).remove(6).state.noVoteDay).toBe(0)
  })

  it("lets tomorrow vote after today's was cancelled", () => {
    const next = game().remove(5).newDay()

    expect(next.nominate(1).do({ type: "start_vote" }).kinds).not.toContain("vote_skipped")
  })

  it("drops a removed candidate", () => {
    expect(game().nominate(3, 4).remove(3).state.candidates).toEqual([4])
  })

  it("keeps the nominator bound after his candidate is removed", () => {
    expect(game().nominate(3).remove(3).try({ type: "nominate", seats: [6] }).error).toBe("already_nominated_today")
  })

  it("cancels tomorrow's vote during the leaving speech", () => {
    const leaving = voting(5, 3).vote(1, 2, 3, 4, 6, 7)

    expect(leaving.remove(9).state.noVoteDay).toBe(1)
  })

  it("keeps the same cancelled vote on a second removal in the leaving speech", () => {
    const leaving = voting(5, 3).vote(1, 2, 3, 4, 6, 7)

    expect(leaving.remove(9).remove(8).state.noVoteDay).toBe(1)
  })

  it("cancels the next day's vote at night", () => {
    expect(game().do({ type: "start_vote" }).remove(9).state.noVoteDay).toBe(1)
  })

  it("moves on to a later day once the cancelled one has passed", () => {
    const later = game().remove(9).do({ type: "start_vote" }).remove(8)

    expect(later.state.noVoteDay).toBe(1)
  })

  it("finishes a decided vote and cancels tomorrow's", () => {
    const decided = voting(1, 2, 3).vote(3, 4, 5, 6, 7).remove(10)

    expect(decided.state).toMatchObject({ stage: "vote", noVoteDay: 1, round: { index: 1 } })
  })

  it("does not write a cancellation for a decided vote", () => {
    expect(voting(1, 2, 3).vote(3, 4, 5, 6, 7).remove(10).kinds).not.toContain("round_cancelled")
  })

  it("cancels an undecided vote at once", () => {
    const undecided = voting(1, 2, 3).vote(3, 4, 5).remove(10)

    expect([undecided.state.stage, undecided.state.round, undecided.kinds.at(-1)]).toEqual(["night_shot", null, "round_cancelled"])
  })

  it("leaves tomorrow's vote alone after that", () => {
    expect(voting(1, 2, 3).vote(3, 4, 5).remove(10).state.noVoteDay).toBeNull()
  })

  it("keeps the vote of a removed player", () => {
    const kept = voting(1, 2, 3).vote(3, 4, 5, 6, 7, 8).remove(8)

    expect(kept.state.round.votes[1]).toEqual([3, 4, 5, 6, 7, 8])
  })

  it("does not call a removed leader to speak", () => {
    const decided = voting(1, 2, 3).vote(3, 4, 5, 6, 7, 8).remove(1).vote()

    expect([decided.state.stage, decided.state.leaving, decided.kinds]).toEqual(["night_shot", [], expect.not.arrayContaining(["nothing"])])
  })

  it("does not write a departure for a removed leader", () => {
    const decided = voting(1, 2, 3).vote(3, 4, 5, 6, 7, 8).remove(1).vote()

    expect(decided.kinds.at(-1)).toBe("round_closed")
  })

  it("does the same through an automatic removal", () => {
    const fouled = voting(1, 2, 3).vote(3, 4, 5).do({ type: "tech", seats: [10] }).do({ type: "tech", seats: [10] })

    expect(fouled.kinds.slice(-3)).toEqual(["tech", "player_left", "round_cancelled"])
  })

  it("skips the vote when the last speaker is removed and it was cancelled", () => {
    const circle = game()
    seats.slice(1).forEach(() => circle.do({ type: "next_speaker" }))

    expect(circle.remove(10).kinds.slice(-2)).toEqual(["player_left", "vote_skipped"])
  })
})

describe("the night stage", () => {
  it("stamps events with the night phase", () => {
    expect(game().do({ type: "start_vote" }).try({ type: "foul", seats: [3] }).events[0].phase).toBe("night")
  })
})

describe("purity", () => {
  it("does not change the state while closing a round", () => {
    const round = voting(5, 3, 4).vote(1, 2, 3, 4, 5, 6)
    const { state } = round
    const before = structuredClone(state)

    decide(state, { type: "vote_for", seats: [] })

    expect(state).toEqual(before)
  })
})
