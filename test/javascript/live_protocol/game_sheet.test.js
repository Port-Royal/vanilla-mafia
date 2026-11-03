import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"
import { buildSheet } from "../../../app/javascript/live_protocol/game_sheet.js"

const players = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((seat) => ({ seat, name: `И${seat}`, role_code: null }))

function stateAfter(actions) {
  const events = []
  actions.forEach((action) => {
    const { events: produced, error } = decide(replay(players, events), action)
    expect(error).toBeNull()
    events.push(...produced)
  })
  return replay(players, events)
}

const start = (deal = {}) => [{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal", ...deal }]
const quietChecks = [{ type: "don_check" }, { type: "sheriff_check" }]
const shown = (actions) => buildSheet(stateAfter(actions), { rolesShown: true })
const hidden = (actions) => buildSheet(stateAfter(actions), { rolesShown: false })
const nominate = (...seats) => seats.flatMap((seat, index) => [{ type: "set_speaker", seats: [index + 1] }, { type: "nominate", seats: [seat] }])
const missAll = [{ type: "miss_shot", seats: [7] }, { type: "miss_shot", miss: "no_shot" }, { type: "miss_shot", miss: "tactical" }]

describe("the deal", () => {
  it("is shown with roles", () => {
    expect(shown(start({ mode: "static", seats: [5], text: "план" })).deal).toEqual({ mode: "static", shot: null, sheriff: 5, text: "план" })
  })

  it("is left out with roles hidden", () => {
    expect(hidden(start({ mode: "static" })).deal).toBeNull()
  })
})

describe("the shooting", () => {
  it("names the target of each night", () => {
    expect(hidden([...start(), { type: "start_vote" }, { type: "shoot", seats: [5] }]).shots).toEqual([{ night: 1, target: 5 }])
  })

  it("writes X for a miss", () => {
    expect(hidden([...start(), { type: "start_vote" }, ...missAll]).shots).toEqual([{ night: 1, target: "X" }])
  })

  it("counts nights in order", () => {
    const sheet = hidden([...start(), { type: "start_vote" }, ...missAll, ...quietChecks, { type: "start_vote" }, { type: "shoot", seats: [8] }])

    expect(sheet.shots).toEqual([{ night: 1, target: "X" }, { night: 2, target: 8 }])
  })

  it("has nothing before the first night", () => {
    expect(hidden(start()).shots).toEqual([])
  })
})

describe("the misses", () => {
  it("say who shot where", () => {
    expect(shown([...start(), { type: "start_vote" }, ...missAll]).misses).toEqual([
      { night: 1, shooter: 1, target: 7, miss: null },
      { night: 1, shooter: 3, target: null, miss: "no_shot" },
      { night: 1, shooter: 4, target: null, miss: "tactical" }
    ])
  })

  it("are left out with roles hidden", () => {
    expect(hidden([...start(), { type: "start_vote" }, ...missAll]).misses).toBeNull()
  })
})

describe("the checks", () => {
  const checked = [...start(), { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }, { type: "sheriff_check", seats: [3] }]

  it("give the seat and the result per night", () => {
    expect(shown(checked).checks).toEqual([{ night: 1, don: { seat: 2, result: "sheriff" }, sheriff: { seat: 3, result: "black" } }])
  })

  it("show no check for a skipped one", () => {
    expect(shown([...start(), { type: "start_vote" }, { type: "shoot", seats: [5] }, ...quietChecks]).checks).toEqual([{ night: 1, don: null, sheriff: null }])
  })

  it("show a night with only one check", () => {
    expect(shown([...start(), { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }]).checks)
      .toEqual([{ night: 1, don: { seat: 2, result: "sheriff" }, sheriff: null }])
  })

  it("are left out with roles hidden", () => {
    expect(hidden(checked).checks).toBeNull()
  })
})

describe("the rounds", () => {
  const voting = [...start(), ...nominate(5, 6), { type: "start_vote" }]
  const votingThree = [...start(), ...nominate(5, 6, 7), { type: "start_vote" }]

  it("say who voted for whom", () => {
    expect(hidden([...voting, { type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }]).rounds).toEqual([{
      day: 0,
      type: "main",
      votes: [{ candidates: [5], voters: [1, 2, 3, 4, 7, 8], auto: [] }, { candidates: [6], voters: [5, 6, 9, 10], auto: [5, 6, 9, 10] }],
      outcome: "leave",
      leaders: [5],
      reason: null
    }])
  })

  it("list a repeat and a lift", () => {
    const tie = [{ type: "vote_for", seats: [1, 2, 3, 4, 7] }]
    const sheet = hidden([...voting, ...tie, ...tie, { type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }])

    expect(sheet.rounds.map((round) => [round.type, round.outcome])).toEqual([["main", "repeat"], ["repeat", "lift"], ["lift", "leave"]])
  })

  it("give the voters of a lift against all the leaders", () => {
    const tie = [{ type: "vote_for", seats: [1, 2, 3, 4, 7] }]
    const sheet = hidden([...voting, ...tie, ...tie, { type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }])

    expect(sheet.rounds[2].votes).toEqual([{ candidates: [5, 6], voters: [1, 2, 3, 4, 7, 8], auto: [] }])
  })

  it("name why a lift was not held", () => {
    const shares = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]].map((seats) => ({ type: "vote_for", seats }))
    const sheet = hidden([...start(), ...nominate(1, 2, 3, 4, 5), { type: "start_vote" }, ...shares.slice(0, -1), ...shares.slice(0, -1)])

    expect(sheet.rounds[1].reason).toBe("five_or_ten_zero")
  })

  it("show a round in progress", () => {
    expect(hidden([...votingThree, { type: "vote_for", seats: [1] }]).rounds).toEqual([{
      day: 0, type: "main", votes: [{ candidates: [5], voters: [1], auto: [] }], outcome: null, leaders: [], reason: null
    }])
  })

  it("show a cancelled round", () => {
    const sheet = hidden([...votingThree, { type: "vote_for", seats: [1] }, { type: "remove_player", seats: [9] }])

    expect(sheet.rounds[0].outcome).toBe("cancelled")
  })

  it("start over the next day as a main round", () => {
    const sheet = hidden([
      ...voting, { type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }, { type: "best_move" }, { type: "finish_leaving" },
      { type: "shoot", seats: [9] }, ...quietChecks, { type: "best_move" }, { type: "finish_leaving" }, ...nominate(7), { type: "start_vote" }
    ])

    expect(sheet.rounds.map((round) => [round.day, round.type])).toEqual([[0, "main"], [1, "main"]])
  })

  it("start as a main round after a cancelled one", () => {
    const sheet = hidden([
      ...votingThree, { type: "vote_for", seats: [1] }, { type: "remove_player", seats: [9] },
      { type: "shoot", seats: [8] }, ...quietChecks, { type: "best_move" }, { type: "finish_leaving" }, ...nominate(7), { type: "start_vote" }
    ])

    expect(sheet.rounds[1].type).toBe("main")
  })

  it("are empty before a vote", () => {
    expect(hidden(start()).rounds).toEqual([])
  })
})

describe("wills and best moves", () => {
  const leaving = [...start(), { type: "start_vote" }, { type: "shoot", seats: [5] }, ...quietChecks]

  it("parse a will and keep its raw text", () => {
    expect(hidden([...leaving, { type: "best_move" }, { type: "will", text: "2к план" }]).wills)
      .toEqual([{ seat: 5, text: "2к план", red: [2], black: [], sheriff: [], plan: "план" }])
  })

  it("list a best move", () => {
    expect(hidden([...leaving, { type: "best_move", seats: [1, 3, 4] }]).bestMoves).toEqual([{ seat: 5, seats: [1, 3, 4], noPoints: false }])
  })

  it("leave out a declined best move", () => {
    expect(hidden([...leaving, { type: "best_move" }]).bestMoves).toEqual([])
  })

  it("mark a best move with no points", () => {
    const sheet = hidden([...start(), { type: "remove_player", seats: [9] }, { type: "remove_player", seats: [10] }, { type: "start_vote" }, { type: "shoot", seats: [5] }, ...quietChecks, { type: "best_move", seats: [1, 3, 4] }])

    expect(sheet.bestMoves[0].noPoints).toBe(true)
  })
})

describe("the sheriff bonus hint", () => {
  const killedNightOne = (mode, seat = 2) => [...start({ mode }), { type: "start_vote" }, { type: "shoot", seats: [seat] }, { type: "don_check" }]

  it("appears for the sheriff killed in Night 1 under a dynamic", () => {
    expect(shown(killedNightOne("dynamic")).sheriffBonusHint).toBe(true)
  })

  it("does not appear under a static", () => {
    expect(shown(killedNightOne("static")).sheriffBonusHint).toBe(false)
  })

  it("does not appear for another player", () => {
    expect(shown(killedNightOne("dynamic", 5)).sheriffBonusHint).toBe(false)
  })

  it("does not appear for a later night", () => {
    const later = [...start({ mode: "dynamic" }), { type: "start_vote" }, ...missAll, ...quietChecks, { type: "start_vote" }, { type: "shoot", seats: [2] }]

    expect(shown(later).sheriffBonusHint).toBe(false)
  })

  it("is left out with roles hidden", () => {
    expect(hidden(killedNightOne("dynamic")).sheriffBonusHint).toBe(false)
  })
})
