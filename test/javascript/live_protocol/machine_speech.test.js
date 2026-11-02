import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"

const seats = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const players = seats.map((seat) => ({ seat, name: `Игрок ${seat}`, role_code: null, status: "alive" }))

const play = (actions, startPlayers = players) => {
  const events = []
  actions.forEach((action) => {
    const { events: produced, error } = decide(replay(startPlayers, events), action)
    expect(error).toBeNull()
    events.push(...produced)
  })
  return events
}

const stateAfter = (actions, startPlayers = players) => replay(startPlayers, play(actions, startPlayers))
const errorAfter = (actions, action) => decide(stateAfter(actions), action)

const assignRoles = { type: "assign_roles", seats: [1, 2, 3, 4] }
const startGame = [assignRoles, { type: "finish_deal" }]
const twoCandidates = [{ type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "set_speaker", seats: [1] }]
const closeNight = { kind: "night_closed", phase: "night", day_number: 0, actor_seat: null, target_seats: [], text: null, metadata: {} }

describe("replay of an empty journal", () => {
  const state = replay(players, [])

  it("starts at the roles stage", () => {
    expect(state.stage).toBe("roles")
  })

  it("lists every seated player alive with no sanctions", () => {
    expect(state.players[3]).toEqual({ name: "Игрок 3", role: null, fouls: 0, tech: 0, out: false, outReason: null, removedBy: null })
  })

  it("leaves empty seats out", () => {
    expect(Object.keys(replay(players.slice(0, 2), []).players)).toEqual(["1", "2"])
  })

  it("takes roles from the form", () => {
    expect(replay([{ seat: 1, name: "А", role_code: "don" }], []).players[1].role).toBe("don")
  })

  it("does not trust a status from the form", () => {
    expect(replay([{ seat: 1, name: "А", role_code: null, status: "banned" }], []).players[1].out).toBe(false)
  })

  it("has an empty day state", () => {
    expect(state).toMatchObject({ day: 0, speaker: null, firstSpeaker: null, candidates: [], nominatedBy: {}, round: null, leaving: [], noVoteDay: null, log: [] })
  })
})

describe("assign_roles", () => {
  it("writes the don, the sheriff, two mafia and peace for the rest", () => {
    const { events } = decide(replay(players.slice(0, 5), []), { type: "assign_roles", seats: [1, 2, 3, 4] })

    expect(events).toEqual([{
      kind: "roles",
      phase: "deal",
      day_number: 0,
      actor_seat: null,
      target_seats: [],
      text: null,
      metadata: {
        roles: { 1: "don", 2: "sheriff", 3: "mafia", 4: "mafia", 5: "peace" },
        previous_roles: { 1: null, 2: null, 3: null, 4: null, 5: null }
      }
    }])
  })

  it("moves to the deal and applies the roles", () => {
    const state = stateAfter([assignRoles])

    expect([state.stage, state.players[1].role, state.players[4].role, state.players[5].role]).toEqual(["deal", "don", "mafia", "peace"])
  })

  it.each([
    ["too few", [1, 2, 3]],
    ["too many", [1, 2, 3, 4, 5]],
    ["a repeated seat", [1, 2, 3, 3]],
    ["no seats", []]
  ])("refuses %s", (_name, chosen) => {
    expect(decide(replay(players, []), { type: "assign_roles", seats: chosen })).toEqual({ events: [], error: "roles_incomplete" })
  })

  it("refuses a seat nobody sits on", () => {
    expect(decide(replay(players.slice(0, 5), []), { type: "assign_roles", seats: [1, 2, 3, 9] }).error).toBe("roles_incomplete")
  })

  describe("without seats", () => {
    const filled = players.map((player) => ({ ...player, role_code: { 1: "don", 2: "sheriff", 3: "mafia", 4: "mafia" }[player.seat] || "peace" }))

    it("confirms a complete set from the form", () => {
      const state = stateAfter([{ type: "assign_roles" }], filled)

      expect([state.stage, state.players[2].role]).toEqual(["deal", "sheriff"])
    })

    it.each([
      ["no don", { 1: "peace" }],
      ["no sheriff", { 2: "peace" }],
      ["one mafia", { 3: "peace" }],
      ["two dons", { 3: "don" }],
      ["a blank role", { 5: null }],
      ["three mafia", { 5: "mafia" }]
    ])("refuses a set with %s", (_name, change) => {
      const broken = filled.map((player) => (player.seat in change ? { ...player, role_code: change[player.seat] } : player))

      expect(decide(replay(broken, []), { type: "assign_roles" }).error).toBe("roles_incomplete")
    })
  })

  it("refuses outside the roles stage", () => {
    expect(errorAfter([assignRoles], assignRoles).error).toBe("wrong_stage")
  })
})

describe("finish_deal", () => {
  const dealt = [assignRoles]

  it("stores the mode, the shot, the claimed sheriff and the text", () => {
    const { events } = errorAfter(dealt, { type: "finish_deal", mode: "dynamic", shot: 7, seats: [5], text: "план" })

    expect(events).toEqual([{
      kind: "deal",
      phase: "deal",
      day_number: 0,
      actor_seat: null,
      target_seats: [5],
      text: "план",
      metadata: { mode: "dynamic", shot: 7 }
    }])
  })

  it("needs nothing filled in", () => {
    const { events } = errorAfter(dealt, { type: "finish_deal" })

    expect(events[0]).toMatchObject({ target_seats: [], text: null, metadata: { mode: null, shot: null } })
  })

  it("keeps the deal in the state", () => {
    const state = stateAfter([assignRoles, { type: "finish_deal", mode: "static", seats: [5], text: "план" }])

    expect(state.deal).toEqual({ mode: "static", shot: null, sheriff: 5, text: "план" })
  })

  it("has no deal details before it", () => {
    expect(replay(players, []).deal).toEqual({ mode: null, shot: null, sheriff: null, text: null })
  })

  it("starts the zero circle with player 1", () => {
    expect(stateAfter(startGame)).toMatchObject({ stage: "speech", day: 0, speaker: 1, firstSpeaker: 1 })
  })

  it("starts with the lowest seat when seat 1 is empty", () => {
    const seated = players.slice(2)

    expect(stateAfter([{ type: "assign_roles", seats: [3, 4, 5, 6] }, { type: "finish_deal" }], seated).speaker).toBe(3)
  })

  it("refuses outside the deal", () => {
    expect(decide(replay(players, []), { type: "finish_deal" }).error).toBe("wrong_stage")
  })

  it("refuses a claimed sheriff nobody sits on", () => {
    expect(decide(replay(players.slice(0, 5), play([assignRoles], players.slice(0, 5))), { type: "finish_deal", seats: [9] }).error).toBe("seat_empty")
  })

  it("refuses more than one claimed sheriff", () => {
    expect(errorAfter(dealt, { type: "finish_deal", seats: [5, 6] })).toEqual({ events: [], error: "one_seat_required" })
  })

  it("refuses a shot nobody sits on", () => {
    expect(decide(replay(players.slice(0, 5), play([assignRoles], players.slice(0, 5))), { type: "finish_deal", shot: 9 }).error).toBe("seat_empty")
  })
})

describe("speech notes", () => {
  it.each([
    ["suspect", "suspect"],
    ["red", "red"],
    ["team", "team"],
    ["check_request", "check_request"]
  ])("%s records the speaker and the named seats", (type, kind) => {
    const { events } = errorAfter(startGame, { type, seats: [4, 7] })

    expect(events).toEqual([{ kind, phase: "day", day_number: 0, actor_seat: 1, target_seats: [4, 7], text: null, metadata: {} }])
  })

  it("drops a seat named twice", () => {
    expect(errorAfter(startGame, { type: "suspect", seats: [4, 4] }).events[0].target_seats).toEqual([4])
  })

  it("refuses no seats", () => {
    expect(errorAfter(startGame, { type: "suspect", seats: [] }).error).toBe("seats_required")
  })

  it("refuses missing seats", () => {
    expect(errorAfter(startGame, { type: "red" }).error).toBe("seats_required")
  })

  it("refuses a seat nobody sits on", () => {
    const seated = players.slice(0, 5)
    const events = play([assignRoles, { type: "finish_deal" }], seated)

    expect(decide(replay(seated, events), { type: "team", seats: [9] }).error).toBe("seat_empty")
  })

  it("refuses when only some of the seats are taken", () => {
    const seated = players.slice(0, 5)
    const events = play([assignRoles, { type: "finish_deal" }], seated)

    expect(decide(replay(seated, events), { type: "team", seats: [2, 9] }).error).toBe("seat_empty")
  })

  it("records a note", () => {
    expect(errorAfter(startGame, { type: "note", text: "врёт" }).events[0]).toMatchObject({ kind: "note", actor_seat: 1, text: "врёт", target_seats: [] })
  })

  it("refuses an empty note", () => {
    expect(errorAfter(startGame, { type: "note", text: "  " }).error).toBe("text_required")
  })

  it("refuses a note with no text", () => {
    expect(errorAfter(startGame, { type: "note" }).error).toBe("text_required")
  })

  it("refuses outside the speech", () => {
    expect(errorAfter([assignRoles], { type: "note", text: "x" }).error).toBe("wrong_stage")
  })

  it("logs every event in order", () => {
    expect(stateAfter([...startGame, { type: "note", text: "x" }]).log.map((event) => event.kind)).toEqual(["roles", "deal", "note"])
  })
})

describe("nominate", () => {
  const nominated = [...startGame, { type: "nominate", seats: [5] }]

  it("records the speaker and the candidate", () => {
    expect(errorAfter(startGame, { type: "nominate", seats: [5] }).events[0])
      .toMatchObject({ kind: "nominate", phase: "day", day_number: 0, actor_seat: 1, target_seats: [5] })
  })

  it("adds the candidate", () => {
    expect(stateAfter(nominated).candidates).toEqual([5])
  })

  it("keeps the order of nomination", () => {
    expect(stateAfter([...nominated, { type: "next_speaker" }, { type: "nominate", seats: [3] }]).candidates).toEqual([5, 3])
  })

  it("refuses a second nomination by the same player", () => {
    expect(errorAfter(nominated, { type: "nominate", seats: [6] })).toEqual({ events: [], error: "already_nominated_today" })
  })

  it("refuses a player already nominated", () => {
    expect(errorAfter([...nominated, { type: "next_speaker" }], { type: "nominate", seats: [5] })).toEqual({ events: [], error: "already_candidate" })
  })

  it("refuses a player who left", () => {
    expect(errorAfter([...startGame, { type: "remove_player", seats: [5] }], { type: "nominate", seats: [5] }).error).toBe("not_alive")
  })

  it("refuses a seat nobody sits on", () => {
    const seated = players.slice(0, 5)
    const events = play([assignRoles, { type: "finish_deal" }], seated)

    expect(decide(replay(seated, events), { type: "nominate", seats: [9] }).error).toBe("not_alive")
  })

  it("refuses anything but one seat", () => {
    expect(errorAfter(startGame, { type: "nominate", seats: [5, 6] }).error).toBe("one_seat_required")
  })

  it("refuses no seat", () => {
    expect(errorAfter(startGame, { type: "nominate" }).error).toBe("one_seat_required")
  })

  it("refuses outside the speech", () => {
    expect(errorAfter([assignRoles], { type: "nominate", seats: [5] }).error).toBe("wrong_stage")
  })
})

describe("cancel_nomination", () => {
  const nominated = [...startGame, { type: "nominate", seats: [5] }]
  const cancelled = [...nominated, { type: "cancel_nomination", seats: [5] }]

  it("records the cancelled candidate", () => {
    expect(errorAfter(nominated, { type: "cancel_nomination", seats: [5] }).events[0])
      .toMatchObject({ kind: "nomination_cancelled", phase: "day", day_number: 0, actor_seat: 1, target_seats: [5] })
  })

  it("removes the candidate", () => {
    expect(stateAfter(cancelled).candidates).toEqual([])
  })

  it("lets the nominator nominate again", () => {
    expect(errorAfter(cancelled, { type: "nominate", seats: [6] }).error).toBeNull()
  })

  it("keeps the other candidates", () => {
    const two = [...nominated, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "cancel_nomination", seats: [5] }]

    expect(stateAfter(two).candidates).toEqual([6])
  })

  it("frees the nominator even when somebody else cancels", () => {
    const later = [...nominated, { type: "next_speaker" }, { type: "cancel_nomination", seats: [5] }, { type: "set_speaker", seats: [1] }]

    expect(errorAfter(later, { type: "nominate", seats: [6] }).error).toBeNull()
  })

  it("keeps other nominators bound", () => {
    const two = [...nominated, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "cancel_nomination", seats: [5] }]

    expect(errorAfter(two, { type: "nominate", seats: [7] }).error).toBe("already_nominated_today")
  })

  it("refuses a seat that is no candidate", () => {
    expect(errorAfter(nominated, { type: "cancel_nomination", seats: [6] })).toEqual({ events: [], error: "not_candidate" })
  })

  it("refuses anything but one seat", () => {
    expect(errorAfter(nominated, { type: "cancel_nomination", seats: [] }).error).toBe("one_seat_required")
  })

  it("refuses outside the speech", () => {
    expect(errorAfter([assignRoles], { type: "cancel_nomination", seats: [5] }).error).toBe("wrong_stage")
  })

  it("makes a deleted nomination count as never made", () => {
    const events = play(nominated)
    const state = replay(players, events.slice(0, -1))

    expect([state.candidates, decide(state, { type: "nominate", seats: [5] }).error]).toEqual([[], null])
  })
})

describe("next_speaker", () => {
  it("records the next player", () => {
    expect(errorAfter(startGame, { type: "next_speaker" }).events).toEqual([
      { kind: "speaker", phase: "day", day_number: 0, actor_seat: 2, target_seats: [], text: null, metadata: {} }
    ])
  })

  it("moves the speaker", () => {
    expect(stateAfter([...startGame, { type: "next_speaker" }]).speaker).toBe(2)
  })

  it("skips a player who left", () => {
    expect(stateAfter([...startGame, { type: "remove_player", seats: [2] }, { type: "next_speaker" }]).speaker).toBe(3)
  })

  it("wraps past seat 10 when the circle started later", () => {
    const fromTen = [...startGame, ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map(() => ({ type: "next_speaker" }))]

    expect(stateAfter(fromTen).speaker).toBe(10)
  })

  it("starts the vote after the last player of the circle", () => {
    const toLast = [...startGame, ...twoCandidates, ...seats.slice(1).map(() => ({ type: "next_speaker" }))]
    const state = stateAfter([...toLast, { type: "next_speaker" }])

    expect([state.stage, state.speaker]).toEqual(["vote", null])
  })

  it("keeps the speech until then", () => {
    const toLast = [...startGame, ...seats.slice(1).map(() => ({ type: "next_speaker" }))]

    expect(stateAfter(toLast).stage).toBe("speech")
  })

  it("marks the move to the vote with no speaker", () => {
    const toLast = [...startGame, ...seats.slice(1).map(() => ({ type: "next_speaker" }))]

    expect(errorAfter(toLast, { type: "next_speaker" }).events[0]).toMatchObject({ kind: "speaker", actor_seat: null })
  })

  it("refuses outside the speech", () => {
    expect(errorAfter([assignRoles], { type: "next_speaker" }).error).toBe("wrong_stage")
  })
})

describe("set_speaker", () => {
  it("makes the clicked player the speaker", () => {
    expect(stateAfter([...startGame, { type: "set_speaker", seats: [6] }]).speaker).toBe(6)
  })

  it("keeps the circle going from there", () => {
    expect(stateAfter([...startGame, { type: "set_speaker", seats: [6] }, { type: "next_speaker" }]).speaker).toBe(7)
  })

  it("attributes the speech to the clicked player", () => {
    expect(errorAfter([...startGame, { type: "set_speaker", seats: [6] }], { type: "note", text: "x" }).events[0].actor_seat).toBe(6)
  })

  it("refuses a player who left", () => {
    expect(errorAfter([...startGame, { type: "remove_player", seats: [6] }], { type: "set_speaker", seats: [6] }).error).toBe("not_alive")
  })

  it("refuses anything but one seat", () => {
    expect(errorAfter(startGame, { type: "set_speaker", seats: [] }).error).toBe("one_seat_required")
  })

  it("refuses outside the speech", () => {
    expect(errorAfter([assignRoles], { type: "set_speaker", seats: [2] }).error).toBe("wrong_stage")
  })
})

describe("start_vote", () => {
  it("goes to the vote before the end of the circle", () => {
    expect(stateAfter([...startGame, ...twoCandidates, { type: "start_vote" }]).stage).toBe("vote")
  })

  it("is written like the automatic move", () => {
    expect(errorAfter(startGame, { type: "start_vote" }).events[0]).toMatchObject({ kind: "speaker", actor_seat: null, phase: "day" })
  })

  it("refuses outside the speech", () => {
    expect(errorAfter([assignRoles], { type: "start_vote" }).error).toBe("wrong_stage")
  })
})

describe("remove_player", () => {
  it("writes player_left with the removal reason", () => {
    expect(errorAfter(startGame, { type: "remove_player", seats: [5] }).events[0]).toMatchObject({
      kind: "player_left", phase: "day", day_number: 0, target_seats: [5], metadata: { reason: "removed" }
    })
  })

  it("marks the player out", () => {
    expect(stateAfter([...startGame, { type: "remove_player", seats: [5] }]).players[5]).toMatchObject({ out: true, outReason: "removed" })
  })

  it("refuses a player already out", () => {
    expect(errorAfter([...startGame, { type: "remove_player", seats: [5] }], { type: "remove_player", seats: [5] }).error).toBe("not_alive")
  })

  it("refuses anything but one seat", () => {
    expect(errorAfter(startGame, { type: "remove_player", seats: [1, 2] }).error).toBe("one_seat_required")
  })

  it("passes the word on when the speaker is removed", () => {
    expect(stateAfter([...startGame, { type: "remove_player", seats: [1] }]).speaker).toBe(2)
  })

  it("leaves the speaker alone when somebody else is removed", () => {
    expect(stateAfter([...startGame, { type: "remove_player", seats: [5] }]).speaker).toBe(1)
  })

  it("finishes the circle when the first speaker was removed along the way", () => {
    const toLast = [...startGame, { type: "remove_player", seats: [1] }, ...seats.slice(2).map(() => ({ type: "next_speaker" }))]
    const atLast = stateAfter(toLast)

    expect([atLast.speaker, stateAfter([...toLast, { type: "next_speaker" }]).stage]).toEqual([10, "night_shot"])
  })

  it("ends the speeches when the last speaker is removed", () => {
    const toLast = [...startGame, ...seats.slice(1).map(() => ({ type: "next_speaker" }))]

    expect(stateAfter([...toLast, { type: "remove_player", seats: [10] }])).toMatchObject({ stage: "night_shot", speaker: null })
  })

  it("does not move the speaker outside the speech", () => {
    const voting = [...startGame, ...twoCandidates, { type: "start_vote" }, { type: "vote_for", seats: [2, 3, 4, 7, 8, 9] }, { type: "remove_player", seats: [1] }]

    expect(stateAfter(voting)).toMatchObject({ stage: "vote", speaker: null })
  })
})

describe("a new day", () => {
  const dayOne = (extra = []) => {
    const events = [...play([...startGame, ...extra]), closeNight]
    return replay(players, events)
  }

  it("starts with the next living player after the last one who started", () => {
    expect(dayOne()).toMatchObject({ stage: "speech", day: 1, firstSpeaker: 2, speaker: 2 })
  })

  it("skips a player who left", () => {
    expect(dayOne([{ type: "remove_player", seats: [2] }]).firstSpeaker).toBe(3)
  })

  it("keeps the same first speaker when nobody else is left", () => {
    const others = seats.slice(1).map((seat) => ({ type: "remove_player", seats: [seat] }))

    expect(dayOne(others).firstSpeaker).toBe(1)
  })

  it("wraps around the table", () => {
    const events = play(startGame)
    for (let night = 0; night < 10; night += 1) events.push({ ...closeNight, day_number: night })

    expect(replay(players, events).firstSpeaker).toBe(1)
  })

  it("forgets the candidates and who nominated", () => {
    const state = dayOne([{ type: "nominate", seats: [5] }])

    expect([state.candidates, decide(state, { type: "nominate", seats: [5] }).error]).toEqual([[], null])
  })

  it("stamps events with the new day", () => {
    expect(decide(dayOne(), { type: "note", text: "x" }).events[0].day_number).toBe(1)
  })
})

describe("purity", () => {
  it("does not change the state in decide", () => {
    const state = stateAfter(startGame)
    const before = structuredClone(state)

    decide(state, { type: "nominate", seats: [5] })

    expect(state).toEqual(before)
  })

  it("does not change the journal in replay", () => {
    const events = play(startGame)
    const before = structuredClone(events)

    replay(players, events)

    expect(events).toEqual(before)
  })

  it("rejects an unknown action", () => {
    expect(decide(replay(players, []), { type: "dance" })).toEqual({ events: [], error: "unknown_action" })
  })

  it("logs a kind it has no rule for", () => {
    const state = replay(players, [{ ...closeNight, kind: "suspect" }])

    expect([state.stage, state.log.length]).toEqual(["roles", 1])
  })
})

describe("previous roles", () => {
  it("keep what the seats held before the event", () => {
    const filled = players.slice(0, 5).map((player) => ({ ...player, role_code: player.seat === 5 ? "don" : null }))

    expect(decide(replay(filled, []), { type: "assign_roles", seats: [1, 2, 3, 4] }).events[0].metadata.previous_roles)
      .toEqual({ 1: null, 2: null, 3: null, 4: null, 5: "don" })
  })
})
