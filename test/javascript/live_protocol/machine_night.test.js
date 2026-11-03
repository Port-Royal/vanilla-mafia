import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"

const seats = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const players = seats.map((seat) => ({ seat, name: `Игрок ${seat}`, role_code: null }))

// Don 1, sheriff 2, mafia 3 and 4, peace 5..10.
function game() {
  const events = []
  const api = {
    do(action) {
      const { events: produced, error } = decide(replay(players, events), action)
      expect(error).toBeNull()
      events.push(...produced)
      return api
    },
    try: (action) => decide(replay(players, events), action),
    get state() { return replay(players, events) },
    get kinds() { return events.map((event) => event.kind) },
    events,
    night() { return api.do({ type: "start_vote" }) },
    shoot(seat) { return api.do({ type: "shoot", seats: [seat] }) },
    checks() { return api.do({ type: "don_check" }).do({ type: "sheriff_check" }) },
    missAll() { return api.do({ type: "miss_shot", miss: "no_shot" }).do({ type: "miss_shot", miss: "no_shot" }).do({ type: "miss_shot", miss: "no_shot" }) },
    quietNight() { return api.night().missAll().checks() },
    voteOut(seat) {
      const voter = seats.filter((other) => other !== seat && !api.state.players[other].out)
      return api.do({ type: "set_speaker", seats: [voter[0]] }).do({ type: "nominate", seats: [seat] })
    }
  }
  return api.do({ type: "assign_roles", seats: [1, 2, 3, 4] }).do({ type: "finish_deal" })
}

const nightOne = () => game().night()
const killedNightOne = (seat = 5) => nightOne().shoot(seat)
const zeroVoteOut = (leader, voters, other = 6) => game()
  .do({ type: "set_speaker", seats: [9] }).do({ type: "nominate", seats: [leader] })
  .do({ type: "set_speaker", seats: [10] }).do({ type: "nominate", seats: [other] })
  .do({ type: "start_vote" }).do({ type: "vote_for", seats: voters })

describe("shoot", () => {
  it("writes the shot and the death", () => {
    expect(nightOne().try({ type: "shoot", seats: [5] }).events).toEqual([
      { kind: "shot", phase: "night", day_number: 0, actor_seat: null, target_seats: [5], text: null, metadata: {} },
      { kind: "player_left", phase: "night", day_number: 0, actor_seat: null, target_seats: [5], text: null, metadata: { reason: "killed" } }
    ])
  })

  it("marks the player killed", () => {
    expect(killedNightOne().state.players[5]).toMatchObject({ out: true, outReason: "killed" })
  })

  it("moves on to the don", () => {
    expect(killedNightOne().state.stage).toBe("night_don")
  })

  it("refuses a dead target", () => {
    expect(nightOne().do({ type: "remove_player", seats: [5] }).try({ type: "shoot", seats: [5] }).error).toBe("not_alive")
  })

  it("refuses anything but one target", () => {
    expect(nightOne().try({ type: "shoot", seats: [5, 6] }).error).toBe("one_seat_required")
  })

  it("refuses outside the shooting step", () => {
    expect(game().try({ type: "shoot", seats: [5] }).error).toBe("wrong_stage")
  })

  it("does not cancel a vote", () => {
    expect(killedNightOne().state.noVoteDay).toBeNull()
  })
})

describe("miss_shot", () => {
  it("asks every living black in seat order", () => {
    const first = nightOne().try({ type: "miss_shot", seats: [7] }).events[0]

    expect(first).toEqual({ kind: "miss_shot", phase: "night", day_number: 0, actor_seat: 1, target_seats: [7], text: null, metadata: { miss: null } })
  })

  it("stays on the miss until everybody answered", () => {
    expect(nightOne().do({ type: "miss_shot", seats: [7] }).state.stage).toBe("night_miss")
  })

  it("moves on to the next shooter", () => {
    expect(nightOne().do({ type: "miss_shot", seats: [7] }).try({ type: "miss_shot", seats: [8] }).events[0].actor_seat).toBe(3)
  })

  it.each(["no_shot", "tactical"])("records %s with no target", (miss) => {
    expect(nightOne().try({ type: "miss_shot", miss }).events[0]).toMatchObject({ target_seats: [], metadata: { miss } })
  })

  it("moves to the don after the last shooter", () => {
    expect(nightOne().missAll().state.stage).toBe("night_don")
  })

  it("kills nobody", () => {
    expect(nightOne().missAll().kinds).not.toContain("player_left")
  })

  it("refuses a dead target", () => {
    expect(nightOne().do({ type: "remove_player", seats: [5] }).try({ type: "miss_shot", seats: [5] }).error).toBe("not_alive")
  })

  it("refuses an unknown kind of miss", () => {
    expect(nightOne().try({ type: "miss_shot", miss: "bogus" }).error).toBe("one_seat_required")
  })

  it("refuses no answer", () => {
    expect(nightOne().try({ type: "miss_shot" }).error).toBe("one_seat_required")
  })

  it("refuses outside the shooting step", () => {
    expect(game().try({ type: "miss_shot", miss: "no_shot" }).error).toBe("wrong_stage")
  })

  it("skips a shooter removed along the way", () => {
    const night = nightOne().do({ type: "remove_player", seats: [3] })

    expect(night.do({ type: "miss_shot", miss: "no_shot" }).try({ type: "miss_shot", miss: "no_shot" }).events[0].actor_seat).toBe(4)
  })

  it("leaves the miss when the last shooter waiting is removed", () => {
    const night = nightOne().do({ type: "miss_shot", miss: "no_shot" }).do({ type: "miss_shot", miss: "no_shot" }).do({ type: "remove_player", seats: [4] })

    expect(night.state.stage).toBe("night_don")
  })

  it("starts each night with nobody asked", () => {
    expect([replay(players, []).missed, game().quietNight().night().state.missed]).toEqual([[], []])
  })

  it("asks everybody again on the next night", () => {
    const night = game().quietNight().night()

    expect(night.try({ type: "miss_shot", miss: "no_shot" }).events[0].actor_seat).toBe(1)
  })
})

describe("the checks", () => {
  it("shows the don that a seat is the sheriff", () => {
    expect(killedNightOne().try({ type: "don_check", seats: [2] }).events[0]).toEqual({
      kind: "don_check", phase: "night", day_number: 0, actor_seat: 1, target_seats: [2], text: null, metadata: { result: "sheriff" }
    })
  })

  it("shows the don that a seat is not the sheriff", () => {
    expect(killedNightOne().try({ type: "don_check", seats: [6] }).events[0].metadata.result).toBe("not_sheriff")
  })

  it("allows the don not to check", () => {
    expect(killedNightOne().try({ type: "don_check" }).events[0]).toMatchObject({ target_seats: [], metadata: { result: null } })
  })

  it("moves on to the sheriff", () => {
    expect(killedNightOne().do({ type: "don_check" }).state.stage).toBe("night_sheriff")
  })

  it.each([[3, "black"], [1, "black"], [6, "red"], [2, "red"]])("shows the sheriff that seat %i is %s", (seat, result) => {
    expect(killedNightOne().do({ type: "don_check" }).try({ type: "sheriff_check", seats: [seat] }).events[0]).toMatchObject({
      kind: "sheriff_check", actor_seat: 2, target_seats: [seat], metadata: { result }
    })
  })

  it("allows the sheriff not to check", () => {
    expect(killedNightOne().do({ type: "don_check" }).try({ type: "sheriff_check", seats: [] }).events[0].metadata.result).toBeNull()
  })

  it("lets the don check the seat killed this night", () => {
    expect(killedNightOne().try({ type: "don_check", seats: [5] }).events[0]).toMatchObject({ target_seats: [5], metadata: { result: "not_sheriff" } })
  })

  it("shows the don a killed sheriff", () => {
    expect(nightOne().shoot(2).try({ type: "don_check", seats: [2] }).events[0].metadata.result).toBe("sheriff")
  })

  it.each([[3, "black"], [6, "red"]])("lets the sheriff check voted-out seat %i and shows %s", (seat, result) => {
    const night = zeroVoteOut(seat, [5, 7, 8, 9, 10, 1], seat === 6 ? 7 : 6)
      .do({ type: "best_move" }).do({ type: "finish_leaving" }).shoot(8).do({ type: "don_check" })

    expect(night.try({ type: "sheriff_check", seats: [seat] }).events[0]).toMatchObject({ target_seats: [seat], metadata: { result } })
  })

  it("lets the sheriff check a removed seat", () => {
    const night = nightOne().do({ type: "remove_player", seats: [6] }).missAll().do({ type: "don_check" })

    expect(night.try({ type: "sheriff_check", seats: [6] }).events[0].metadata.result).toBe("red")
  })

  it("refuses a seat with no player", () => {
    expect(killedNightOne().try({ type: "don_check", seats: [11] }).error).toBe("seat_empty")
  })

  it("refuses several targets", () => {
    expect(killedNightOne().try({ type: "don_check", seats: [6, 7] }).error).toBe("one_seat_required")
  })

  it("refuses the don outside his step", () => {
    expect(nightOne().try({ type: "don_check" }).error).toBe("wrong_stage")
  })

  it("refuses the sheriff outside his step", () => {
    expect(killedNightOne().try({ type: "sheriff_check" }).error).toBe("wrong_stage")
  })

  it("skips a dead don", () => {
    expect(game().do({ type: "remove_player", seats: [1] }).night().shoot(5).state.stage).toBe("night_sheriff")
  })

  it("skips a sheriff killed that night", () => {
    const night = nightOne().shoot(2).do({ type: "don_check" })

    expect(night.kinds.at(-1)).toBe("night_closed")
  })

  it("skips the don when he is removed during his step", () => {
    expect(killedNightOne().do({ type: "remove_player", seats: [1] }).state.stage).toBe("night_sheriff")
  })

  it("closes the night when the sheriff is removed during his step", () => {
    expect(killedNightOne().do({ type: "don_check" }).do({ type: "remove_player", seats: [2] }).kinds.at(-1)).toBe("night_closed")
  })

  it("keeps the sheriff's step when somebody else is removed", () => {
    expect(killedNightOne().do({ type: "don_check" }).do({ type: "remove_player", seats: [9] }).state.stage).toBe("night_sheriff")
  })

  it("keeps the shooting step when the sheriff is removed", () => {
    expect(nightOne().do({ type: "remove_player", seats: [2] }).state.stage).toBe("night_shot")
  })

  it("closes the night when a removal ends the game", () => {
    const round = game().do({ type: "remove_player", seats: [3] }).do({ type: "remove_player", seats: [4] }).night()

    expect(round.do({ type: "remove_player", seats: [1] }).kinds.at(-1)).toBe("night_closed")
  })

  it("keeps the step when somebody else is removed", () => {
    expect(killedNightOne().do({ type: "remove_player", seats: [9] }).state.stage).toBe("night_don")
  })

  it("closes the night after the last check", () => {
    expect(killedNightOne().do({ type: "don_check" }).do({ type: "sheriff_check" }).events.at(-1)).toMatchObject({ kind: "night_closed", phase: "night", day_number: 0 })
  })
})

describe("the morning", () => {
  it("starts the next day after a quiet night", () => {
    expect(game().quietNight().state).toMatchObject({ stage: "speech", day: 1, speaker: 2, firstSpeaker: 2 })
  })

  it("counts the nights", () => {
    expect(game().quietNight().night().state.nights).toBe(2)
  })

  it("gives the killed player the leaving speech with nobody speaking", () => {
    const morning = game().quietNight().night().shoot(5).checks()

    expect(morning.state).toMatchObject({ stage: "leaving", leaving: [5], speaker: null, day: 2 })
  })

  it("starts the speeches after the leaving speech", () => {
    const morning = game().quietNight().night().shoot(5).checks().do({ type: "finish_leaving" })

    expect(morning.state).toMatchObject({ stage: "speech", leaving: [], speaker: 3, firstSpeaker: 3 })
  })

  it("skips the first speaker who was removed in the leaving speech", () => {
    const morning = game().quietNight().night().shoot(5).checks().do({ type: "remove_player", seats: [3] }).do({ type: "finish_leaving" })

    expect(morning.state.speaker).toBe(4)
  })

  it("cancels today's vote for a removal in that leaving speech", () => {
    const morning = game().quietNight().night().shoot(5).checks().do({ type: "remove_player", seats: [9] })

    expect(morning.state.noVoteDay).toBe(2)
  })

  it("cancels today's vote for a removal during that best move", () => {
    expect(killedNightOne().checks().do({ type: "remove_player", seats: [9] }).state.noVoteDay).toBe(1)
  })
})

describe("a removal on a later day", () => {
  it("cancels tomorrow's vote when today's is decided", () => {
    const later = game().quietNight().night().shoot(5).checks().do({ type: "finish_leaving" })
    later.do({ type: "set_speaker", seats: [9] }).do({ type: "nominate", seats: [6] })
    later.do({ type: "set_speaker", seats: [10] }).do({ type: "nominate", seats: [7] })
    later.do({ type: "set_speaker", seats: [1] }).do({ type: "nominate", seats: [8] }).do({ type: "start_vote" })
    later.do({ type: "vote_for", seats: [1, 2, 3, 4, 8, 9] }).do({ type: "remove_player", seats: [10] })

    expect(later.state).toMatchObject({ stage: "vote", noVoteDay: 3 })
  })
})

describe("finish_leaving", () => {
  const leaving = () => zeroVoteOut(5, [5, 7, 8, 9, 10, 1])

  it("remembers that the speech came after a vote", () => {
    expect(leaving().state.leavingAfter).toBe("vote")
  })

  it("refuses during the best move", () => {
    expect(killedNightOne().checks().try({ type: "finish_leaving" }).error).toBe("wrong_stage")
  })

  it("refuses with nobody left to speak", () => {
    const round = game()
    ;[6, 7, 8].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))
    round.night().shoot(5).do({ type: "best_move" }).do({ type: "finish_leaving" })

    expect(round.try({ type: "finish_leaving" }).error).toBe("wrong_stage")
  })

  it("writes that the speech is over", () => {
    expect(leaving().try({ type: "finish_leaving" }).events[0]).toMatchObject({ kind: "leaving_closed", phase: "day", actor_seat: 5, target_seats: [] })
  })

  it("goes to the night after a vote", () => {
    expect(leaving().do({ type: "finish_leaving" }).state).toMatchObject({ stage: "night_shot", leaving: [] })
  })

  it("takes the next player when several left", () => {
    const lifted = game().do({ type: "set_speaker", seats: [9] }).do({ type: "nominate", seats: [5] })
    lifted.do({ type: "set_speaker", seats: [10] }).do({ type: "nominate", seats: [6] }).do({ type: "start_vote" })
    lifted.do({ type: "vote_for", seats: [5, 7, 8, 9, 10] })
    lifted.do({ type: "vote_for", seats: [5, 7, 8, 9, 10] })
    lifted.do({ type: "vote_for", seats: [1, 2, 3, 4, 7, 8] })
    const stageBefore = lifted.state.leaving

    expect([stageBefore, lifted.do({ type: "finish_leaving" }).state.leaving]).toEqual([[5, 6], [6]])
  })

  it("refuses outside the leaving speech", () => {
    expect(game().try({ type: "finish_leaving" }).error).toBe("wrong_stage")
  })
})

describe("will", () => {
  const leaving = () => zeroVoteOut(5, [5, 7, 8, 9, 10, 1])

  it("stores the raw text against the leaving player", () => {
    expect(leaving().try({ type: "will", text: "234к, план" }).events).toEqual([
      { kind: "will", phase: "day", day_number: 0, actor_seat: 5, target_seats: [], text: "234к, план", metadata: {} }
    ])
  })

  it("stays in the speech", () => {
    expect(leaving().do({ type: "will", text: "план" }).state.stage).toBe("leaving")
  })

  it("refuses an empty will", () => {
    expect(leaving().try({ type: "will", text: " " }).error).toBe("text_required")
  })

  it("refuses a will with no text", () => {
    expect(leaving().try({ type: "will" }).error).toBe("text_required")
  })

  it("refuses before the best move", () => {
    expect(killedNightOne().checks().try({ type: "will", text: "план" }).error).toBe("wrong_stage")
  })

  it("refuses when nobody is leaving", () => {
    expect(game().try({ type: "will", text: "план" }).error).toBe("wrong_stage")
  })
})

describe("best move at night", () => {
  it("is offered to the player killed in Night 1", () => {
    expect(killedNightOne().checks().state).toMatchObject({ stage: "best_move", leaving: [5], day: 1 })
  })

  it("is not offered in later nights", () => {
    expect(game().quietNight().night().shoot(5).checks().state.stage).toBe("leaving")
  })

  it("records the three named seats", () => {
    expect(killedNightOne().checks().try({ type: "best_move", seats: [1, 3, 4] }).events).toEqual([
      { kind: "best_move", phase: "day", day_number: 1, actor_seat: 5, target_seats: [1, 3, 4], text: null, metadata: {} }
    ])
  })

  it("goes on to the will", () => {
    expect(killedNightOne().checks().do({ type: "best_move", seats: [1, 3, 4] }).state.stage).toBe("leaving")
  })

  it("may be declined", () => {
    const declined = killedNightOne().checks().do({ type: "best_move", seats: [] })

    expect([declined.state.stage, declined.events.at(-1).target_seats]).toEqual(["leaving", []])
  })

  it("may be declined with no seats given", () => {
    expect(killedNightOne().checks().do({ type: "best_move" }).state.stage).toBe("leaving")
  })

  it.each([
    ["two seats", [1, 3]],
    ["four seats", [1, 3, 4, 6]],
    ["a repeated seat", [1, 3, 3]],
    ["four seats with a repeat", [1, 3, 3, 4]]
  ])("refuses %s", (_name, chosen) => {
    expect(killedNightOne().checks().try({ type: "best_move", seats: chosen }).error).toBe("three_seats_required")
  })

  it("refuses his own seat", () => {
    expect(killedNightOne().checks().try({ type: "best_move", seats: [5, 3, 4] }).error).toBe("three_seats_required")
  })

  it("refuses a seat out of range", () => {
    expect(killedNightOne().checks().try({ type: "best_move", seats: [1, 3, 11] }).error).toBe("three_seats_required")
  })

  it("refuses outside the speech", () => {
    expect(game().try({ type: "best_move", seats: [1, 3, 4] }).error).toBe("wrong_stage")
  })

  it("marks no points after 2 departures in the zero circle", () => {
    const night = game().do({ type: "remove_player", seats: [9] }).do({ type: "remove_player", seats: [10] }).night().shoot(5).checks()

    expect(night.try({ type: "best_move", seats: [1, 3, 4] }).events[0].metadata).toEqual({ no_points: true })
  })

  it("gives points after 1 departure in the zero circle", () => {
    const night = game().do({ type: "remove_player", seats: [10] }).night().shoot(5).checks()

    expect(night.try({ type: "best_move", seats: [1, 3, 4] }).events[0].metadata).toEqual({})
  })

  it("does not count a departure in the night", () => {
    const night = game().do({ type: "remove_player", seats: [10] }).night().do({ type: "remove_player", seats: [9] }).shoot(5).checks()

    expect(night.try({ type: "best_move", seats: [1, 3, 4] }).events[0].metadata).toEqual({})
  })

  it("does not count a departure on a later day", () => {
    const night = game().do({ type: "remove_player", seats: [10] }).night().shoot(5).checks().do({ type: "remove_player", seats: [9] })

    expect(night.try({ type: "best_move", seats: [1, 3, 4] }).events[0].metadata).toEqual({})
  })

  it("still counts the others when a player is brought back", () => {
    const back = game().do({ type: "remove_player", seats: [8] }).do({ type: "tech", seats: [9] }).do({ type: "tech", seats: [9] }).do({ type: "cancel_tech", seats: [9] })
    const night = back.do({ type: "remove_player", seats: [10] }).night().shoot(5).checks()

    expect(night.try({ type: "best_move", seats: [1, 3, 4] }).events[0].metadata).toEqual({ no_points: true })
  })

  it("does not count a player brought back", () => {
    const back = game().do({ type: "tech", seats: [9] }).do({ type: "tech", seats: [9] }).do({ type: "cancel_tech", seats: [9] })
    const night = back.do({ type: "remove_player", seats: [10] }).night().shoot(5).checks()

    expect(night.try({ type: "best_move", seats: [1, 3, 4] }).events[0].metadata).toEqual({})
  })
})

describe("best move by day", () => {
  it("is offered to the single player voted out in the zero circle", () => {
    expect(zeroVoteOut(5, [1, 2, 3, 4, 7, 8]).state.stage).toBe("best_move")
  })

  it("is not offered after a vote for himself", () => {
    expect(zeroVoteOut(5, [5, 1, 2, 3, 4, 7]).state.stage).toBe("leaving")
  })

  it("is not offered after an automatic vote for himself", () => {
    const round = game()
      .do({ type: "set_speaker", seats: [9] }).do({ type: "nominate", seats: [6] })
      .do({ type: "set_speaker", seats: [10] }).do({ type: "nominate", seats: [5] })
      .do({ type: "start_vote" }).do({ type: "vote_for", seats: [1, 2] })

    expect([round.state.leaving, round.state.stage]).toEqual([[5], "leaving"])
  })

  it("is not offered on later days", () => {
    const later = game().quietNight()
    later.do({ type: "set_speaker", seats: [9] }).do({ type: "nominate", seats: [5] })

    expect(later.do({ type: "start_vote" }).state.stage).toBe("leaving")
  })

  it("is not offered on a later day even with no vote for himself", () => {
    const later = game().quietNight()
    later.do({ type: "set_speaker", seats: [9] }).do({ type: "nominate", seats: [5] })
    later.do({ type: "set_speaker", seats: [10] }).do({ type: "nominate", seats: [6] }).do({ type: "start_vote" })

    expect(later.do({ type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }).state.stage).toBe("leaving")
  })

  it("can still be recorded with B", () => {
    const leaving = zeroVoteOut(5, [5, 1, 2, 3, 4, 7])

    expect(leaving.try({ type: "best_move", seats: [1, 3, 4] }).events[0]).toMatchObject({ kind: "best_move", actor_seat: 5 })
  })

  it("keeps the stage when recorded with B", () => {
    const leaving = zeroVoteOut(5, [5, 1, 2, 3, 4, 7])

    expect(leaving.do({ type: "best_move", seats: [1, 3, 4] }).state.stage).toBe("leaving")
  })

  it("refuses to decline with B", () => {
    const leaving = zeroVoteOut(5, [5, 1, 2, 3, 4, 7])

    expect(leaving.try({ type: "best_move", seats: [] }).error).toBe("three_seats_required")
  })
})

describe("the end of the game", () => {
  const blacksOut = () => game().do({ type: "remove_player", seats: [1] }).do({ type: "remove_player", seats: [3] }).do({ type: "remove_player", seats: [4] })
  const redsDown = () => {
    const round = game()
    ;[5, 6, 7, 8].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))
    return round
  }

  it("has no result at the start", () => {
    expect(game().state.pendingResult).toBeNull()
  })

  it("sets a peace win when no blacks are left", () => {
    expect(blacksOut().state.pendingResult).toBe("peace_victory")
  })

  it("sets a mafia win when blacks are as many as reds", () => {
    expect(redsDown().state.pendingResult).toBe("mafia_victory")
  })

  it("has no result with one red more", () => {
    const round = game()
    ;[5, 6, 7].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))

    expect(round.state.pendingResult).toBeNull()
  })

  it("takes the result back when a player returns", () => {
    const round = game().do({ type: "remove_player", seats: [1] }).do({ type: "remove_player", seats: [3] })
    round.do({ type: "tech", seats: [4] }).do({ type: "tech", seats: [4] })
    const won = round.state.pendingResult

    expect([won, round.do({ type: "cancel_tech", seats: [4] }).state.pendingResult]).toEqual(["peace_victory", null])
  })

  it("keeps the leaving speech for the will", () => {
    const round = game()
    ;[6, 7, 8].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))
    round.night().shoot(5)

    expect(round.state).toMatchObject({ stage: "best_move", pendingResult: "mafia_victory", leaving: [5] })
  })

  it("skips the checks once the shot ended the game", () => {
    const round = game()
    ;[6, 7, 8].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))

    expect(round.night().shoot(5).kinds.slice(-2)).toEqual(["player_left", "night_closed"])
  })

  it("stays on the speech after the will", () => {
    const round = game()
    ;[6, 7, 8].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))
    round.night().shoot(5).do({ type: "best_move" }).do({ type: "finish_leaving" })

    expect(round.state).toMatchObject({ stage: "leaving", leaving: [] })
  })

  it("does not take a will with nobody left to speak", () => {
    const round = game()
    ;[6, 7, 8].forEach((seat) => round.do({ type: "remove_player", seats: [seat] }))
    round.night().shoot(5).do({ type: "best_move" }).do({ type: "finish_leaving" })

    expect(round.try({ type: "will", text: "план" }).error).toBe("wrong_stage")
  })

  it("does not change the result in the journal before finish_game", () => {
    expect(blacksOut().kinds).not.toContain("game_finished")
  })

  it("writes the pending result on finish_game", () => {
    expect(blacksOut().try({ type: "finish_game" }).events).toEqual([
      { kind: "game_finished", phase: "day", day_number: 0, actor_seat: null, target_seats: [], text: null, metadata: { result: "peace_victory" } }
    ])
  })

  it("lets the judge pick the result", () => {
    expect(blacksOut().try({ type: "finish_game", result: "draw" }).events[0].metadata.result).toBe("draw")
  })

  it.each(["peace_victory", "mafia_victory", "draw"])("accepts %s from the judge", (result) => {
    expect(game().try({ type: "finish_game", result }).events[0].metadata.result).toBe(result)
  })

  it("accepts a draw with no pending result", () => {
    expect(game().do({ type: "finish_game", result: "draw" }).state.stage).toBe("finished")
  })

  it("refuses to finish with no result", () => {
    expect(game().try({ type: "finish_game" }).error).toBe("result_required")
  })

  it("refuses an unknown result", () => {
    expect(game().try({ type: "finish_game", result: "in_progress" }).error).toBe("result_required")
  })

  it("refuses before the game starts", () => {
    expect(decide(replay(players, []), { type: "finish_game", result: "draw" }).error).toBe("wrong_stage")
  })

  it.each(["foul", "remove_player", "cancel_foul"])("refuses %s after the end", (type) => {
    expect(game().do({ type: "finish_game", result: "draw" }).try({ type, seats: [5] }).error).toBe("wrong_stage")
  })

  it("refuses to finish twice", () => {
    expect(game().do({ type: "finish_game", result: "draw" }).try({ type: "finish_game", result: "draw" }).error).toBe("wrong_stage")
  })
})

describe("the draw suggestion", () => {
  it("is off at the start", () => {
    expect(game().state.drawSuggested).toBe(false)
  })

  it("stays off after two quiet nights", () => {
    expect(game().quietNight().quietNight().state.drawSuggested).toBe(false)
  })

  it("comes on after three quiet nights", () => {
    expect(game().quietNight().quietNight().quietNight().state.drawSuggested).toBe(true)
  })

  it("starts counting again after a change among the living", () => {
    const round = game().quietNight().quietNight().do({ type: "remove_player", seats: [9] }).night()
    round.missAll().checks()

    expect(round.state.drawSuggested).toBe(false)
  })

  it("comes on three nights after that change", () => {
    const round = game().quietNight().do({ type: "remove_player", seats: [9] }).night()
    round.missAll().checks().quietNight().quietNight().quietNight()

    expect(round.state.drawSuggested).toBe(true)
  })
})

describe("a removed shooter", () => {
  it("leaves the others to shoot", () => {
    expect(nightOne().do({ type: "remove_player", seats: [3] }).shoot(5).state.players[5].out).toBe(true)
  })
})
