import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"
import { playerEvents } from "../../../app/javascript/live_protocol/player_events.js"

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

const start = [{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }]
const kinds = (entries) => entries.map((event) => event.kind)
const voting = [...start, { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }]

describe("playerEvents", () => {
  const suspicion = stateAfter([...start, { type: "suspect", seats: [4] }])

  it("puts a suspicion in the actions of who suspects", () => {
    expect(kinds(playerEvents(suspicion, 1).actions)).toEqual(["suspect"])
  })

  it("puts it in what the suspected player received", () => {
    expect(kinds(playerEvents(suspicion, 4).received)).toEqual(["suspect"])
  })

  it("leaves it out for anybody else", () => {
    expect(playerEvents(suspicion, 5)).toEqual({ actions: [], received: [] })
  })

  it("keeps the phase and the day of the record", () => {
    expect(playerEvents(suspicion, 1).actions[0]).toMatchObject({ phase: "day", day_number: 0 })
  })

  it("leaves out speaking turns and stage moves", () => {
    const moved = stateAfter([...start, { type: "next_speaker" }, { type: "start_vote" }])

    expect(playerEvents(moved, 2)).toEqual({ actions: [], received: [] })
  })

  describe("votes", () => {
    const voted = stateAfter([...voting, { type: "vote_for", seats: [1, 5] }])

    it("count as an action of each voter", () => {
      expect(kinds(playerEvents(voted, 1).actions)).toEqual(["nominate", "vote"])
    })

    it("count as received by the candidate", () => {
      expect(kinds(playerEvents(voted, 5).received)).toEqual(["nominate", "vote"])
    })

    it("show a vote for himself in both blocks", () => {
      const own = playerEvents(voted, 5)

      expect([kinds(own.actions), kinds(own.received)]).toEqual([["vote"], ["nominate", "vote"]])
    })

    it("count an automatic vote", () => {
      const done = stateAfter([...voting, { type: "vote_for", seats: [1] }, { type: "vote_for", seats: [] }])

      expect(kinds(playerEvents(done, 9).actions)).toEqual(["vote"])
    })
  })

  it("leaves out every stage move of a whole game", () => {
    const game = stateAfter([
      ...start, { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" },
      { type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }, { type: "vote_for", seats: [] }, { type: "best_move" }, { type: "finish_leaving" },
      { type: "miss_shot", miss: "no_shot" }, { type: "miss_shot", miss: "no_shot" }, { type: "miss_shot", miss: "no_shot" },
      { type: "don_check" }, { type: "sheriff_check" }, { type: "start_vote" }, { type: "finish_game", result: "draw" }
    ])
    const seen = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].flatMap((seat) => {
      const { actions, received } = playerEvents(game, seat)
      return kinds([...actions, ...received])
    })
    const noise = ["speaker", "leaving_closed", "roles", "deal", "night_closed", "vote_skipped", "round_cancelled", "round_closed", "game_finished"]

    expect(seen.filter((kind) => noise.includes(kind))).toEqual([])
  })

  it("leaves out a cancelled round", () => {
    const cancelled = stateAfter([...voting, { type: "vote_for", seats: [1] }, { type: "remove_player", seats: [9] }])

    expect(kinds(playerEvents(cancelled, 5).received)).not.toContain("round_cancelled")
  })

  describe("sanctions", () => {
    it("keep technical fouls, their cancellation and the return among the actions", () => {
      const back = stateAfter([...start, { type: "tech", seats: [7] }, { type: "tech", seats: [7] }, { type: "cancel_tech", seats: [7] }])

      expect([kinds(playerEvents(back, 7).actions), playerEvents(back, 7).received]).toEqual([
        ["tech", "tech", "player_left", "sanction_cancelled", "player_restored"], []
      ])
    })


    const fouled = stateAfter([...start, { type: "foul", seats: [7] }, { type: "remove_player", seats: [7] }])

    it("belong to the actions of the player", () => {
      expect(kinds(playerEvents(fouled, 7).actions)).toEqual(["foul", "player_left"])
    })

    it("are not received", () => {
      expect(playerEvents(fouled, 7).received).toEqual([])
    })
  })

  describe("the night", () => {
    const night = stateAfter([...start, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }, { type: "sheriff_check", seats: [3] }])

    it("gives the shot to every living black", () => {
      expect([1, 3, 4].map((seat) => kinds(playerEvents(night, seat).actions))).toEqual([["shot", "don_check"], ["shot"], ["shot"]])
    })

    it("does not give the shot to a black who was out", () => {
      const removed = stateAfter([...start, { type: "remove_player", seats: [4] }, { type: "start_vote" }, { type: "shoot", seats: [5] }])

      expect(kinds(playerEvents(removed, 4).actions)).toEqual(["player_left"])
    })

    it("still gives the shot when somebody else left first", () => {
      const removed = stateAfter([...start, { type: "remove_player", seats: [9] }, { type: "start_vote" }, { type: "shoot", seats: [5] }])

      expect(kinds(playerEvents(removed, 4).actions)).toEqual(["shot"])
    })

    it("does not count a black as out for a record merely naming them", () => {
      const named = stateAfter([...start, { type: "suspect", seats: [4] }, { type: "start_vote" }, { type: "shoot", seats: [5] }])

      expect(kinds(playerEvents(named, 4).actions)).toEqual(["shot"])
    })

    it("gives the shot to a black who came back", () => {
      const back = stateAfter([...start, { type: "tech", seats: [4] }, { type: "tech", seats: [4] }, { type: "cancel_tech", seats: [4] }, { type: "start_vote" }, { type: "shoot", seats: [5] }])

      expect(kinds(playerEvents(back, 4).actions)).toContain("shot")
    })

    it("puts the shot in what the target received", () => {
      expect(kinds(playerEvents(night, 5).received)).toEqual(["shot"])
    })

    it("puts the death in the actions of the killed player", () => {
      expect(kinds(playerEvents(night, 5).actions)).toEqual(["player_left"])
    })

    it("puts the checks in the actions of who checked and the received of who was checked", () => {
      expect([kinds(playerEvents(night, 2).actions), kinds(playerEvents(night, 2).received)]).toEqual([["sheriff_check"], ["don_check"]])
    })

    it("gives each shooter's miss to that shooter", () => {
      const missed = stateAfter([...start, { type: "start_vote" }, { type: "miss_shot", seats: [6] }, { type: "miss_shot", miss: "no_shot" }])

      expect([kinds(playerEvents(missed, 1).actions), kinds(playerEvents(missed, 3).actions), kinds(playerEvents(missed, 6).received)])
        .toEqual([["miss_shot"], ["miss_shot"], ["miss_shot"]])
    })
  })

  describe("wills and best moves", () => {
    const leaving = [...start, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }]

    it("count a will that names the player", () => {
      const will = stateAfter([...leaving, { type: "best_move" }, { type: "will", text: "2к, 9ч, план" }])

      expect([kinds(playerEvents(will, 9).received), kinds(playerEvents(will, 2).received)]).toEqual([["will"], ["will"]])
    })

    it("leave out a will that does not", () => {
      const will = stateAfter([...leaving, { type: "best_move" }, { type: "will", text: "стреляйте в 8" }])

      expect(playerEvents(will, 8).received).toEqual([])
    })

    it("give the will to its author", () => {
      const will = stateAfter([...leaving, { type: "best_move" }, { type: "will", text: "план" }])

      expect(kinds(playerEvents(will, 5).actions)).toContain("will")
    })

    it("count a best move that names the player", () => {
      const move = stateAfter([...leaving, { type: "best_move", seats: [1, 3, 4] }])

      expect(kinds(playerEvents(move, 3).received)).toEqual(["best_move"])
    })
  })
})
