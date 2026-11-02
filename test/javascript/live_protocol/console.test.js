import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"
import { canDelete, digitOf, emptyUi, handleKey, restorePlayers, rolesShown, stamp, undoGroup } from "../../../app/javascript/live_protocol/console.js"

const players = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((seat) => ({ seat, name: `И${seat}`, role_code: null }))
const key = (code, extra = {}) => ({ code, shift: false, ctrl: false, repeat: false, ...extra })

function session(actions = []) {
  const events = []
  actions.forEach((action) => {
    const result = decide(replay(players, events), action)
    expect(result.error).toBeNull()
    events.push(...result.events)
  })
  return replay(players, events)
}

const speech = () => session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }])
const night = () => session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }])
const press = (ui, state, ...codes) => codes.reduce((last, code) => handleKey(last.ui, state, key(code)), { ui })

describe("digitOf", () => {
  it.each([["Digit1", 1], ["Digit9", 9], ["Digit0", 10], ["Numpad3", 3], ["Numpad0", 10], ["KeyA", null], ["Enter", null]])("reads %s", (code, seat) => {
    expect(digitOf(code)).toBe(seat)
  })
})

describe("keys anywhere", () => {
  it("asks to undo on Ctrl+Z", () => {
    expect(handleKey(emptyUi(), speech(), key("KeyZ", { ctrl: true })).undo).toBe(true)
  })

  it("ignores other Ctrl combinations", () => {
    expect(handleKey(emptyUi(), speech(), key("KeyS", { ctrl: true })).ui.pending).toBeNull()
  })

  it("opens roles while H is held", () => {
    expect(handleKey(emptyUi(), speech(), key("KeyH")).ui.reveal).toBe(true)
  })

  it("does nothing on a repeat of a held key", () => {
    const ui = emptyUi()

    expect(handleKey(ui, speech(), key("KeyH", { repeat: true }))).toEqual({ ui })
  })

  it("cancels the pending action on Esc", () => {
    expect(press(emptyUi(), speech(), "KeyS", "Escape").ui.pending).toBeNull()
  })

  it("hints when a number comes with no action", () => {
    expect(press(emptyUi(), speech(), "Digit3").hint).toBe("choose_action")
  })

  it("does nothing after the end of the game", () => {
    const over = session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "finish_game", result: "draw" }])

    expect(press(emptyUi(), over, "KeyF").ui.pending).toBeNull()
  })
})

describe("the roles step", () => {
  const roles = replay(players, [])

  it("collects seats", () => {
    expect(press(emptyUi(), roles, "Digit1", "Digit2").ui.marks).toEqual([1, 2])
  })

  it("takes a seat back when pressed again", () => {
    expect(press(emptyUi(), roles, "Digit1", "Digit1").ui.marks).toEqual([])
  })

  it("assigns the seats on Enter", () => {
    expect(press(emptyUi(), roles, "Digit1", "Digit2", "Digit3", "Digit4", "Enter").action).toEqual({ type: "assign_roles", seats: [1, 2, 3, 4] })
  })

  it("confirms the form's roles on Enter with no seats", () => {
    expect(press(emptyUi(), roles, "Enter").action).toEqual({ type: "assign_roles" })
  })

  it("clears the seats on Esc", () => {
    expect(press(emptyUi(), roles, "Digit1", "Escape").ui.marks).toEqual([])
  })
})

describe("the deal", () => {
  const deal = session([{ type: "assign_roles", seats: [1, 2, 3, 4] }])

  it.each([["KeyS", "static"], ["KeyD", "dynamic"]])("%s sets the mode", (code, mode) => {
    expect(press(emptyUi(), deal, code).ui.deal.mode).toBe(mode)
  })

  it("switches the mode off when pressed again", () => {
    expect(press(emptyUi(), deal, "KeyS", "KeyS").ui.deal.mode).toBeNull()
  })

  it("a number sets the claimed sheriff", () => {
    expect(press(emptyUi(), deal, "Digit5").ui.deal.sheriff).toBe(5)
  })

  it("the same number clears it", () => {
    expect(press(emptyUi(), deal, "Digit5", "Digit5").ui.deal.sheriff).toBeNull()
  })

  it("W puts the cursor in the text field", () => {
    expect(press(emptyUi(), deal, "KeyW").focus).toBe("deal_text")
  })

  it("Enter finishes the deal", () => {
    const ui = { ...press(emptyUi(), deal, "KeyD", "Digit5").ui }
    ui.deal = { ...ui.deal, text: "план" }

    expect(handleKey(ui, deal, key("Enter")).action).toEqual({ type: "finish_deal", mode: "dynamic", seats: [5], text: "план" })
  })

  it("Enter with nothing filled in sends no seats", () => {
    expect(press(emptyUi(), deal, "Enter").action).toEqual({ type: "finish_deal", mode: null, seats: [], text: null })
  })
})

describe("the speech", () => {
  it.each([["KeyS", "suspect"], ["KeyR", "red"], ["KeyT", "team"], ["KeyC", "check_request"]])("%s takes several seats and Enter saves", (code, type) => {
    expect(press(emptyUi(), speech(), code, "Digit2", "Digit0", "Enter").action).toEqual({ type, seats: [2, 10] })
  })

  it("takes a seat back when pressed again", () => {
    expect(press(emptyUi(), speech(), "KeyS", "Digit2", "Digit2").ui.pending.seats).toEqual([])
  })

  it("Enter with no seats just closes the action", () => {
    const done = press(emptyUi(), speech(), "KeyS", "Enter")

    expect([done.action, done.ui.pending]).toEqual([undefined, null])
  })

  it("N saves at once on one number", () => {
    expect(press(emptyUi(), speech(), "KeyN", "Digit5").action).toEqual({ type: "nominate", seats: [5] })
  })

  it("closes the action after saving", () => {
    expect(press(emptyUi(), speech(), "KeyN", "Digit5").ui.pending).toBeNull()
  })

  it("Shift+N cancels a nomination", () => {
    const state = speech()
    const opened = handleKey(emptyUi(), state, key("KeyN", { shift: true }))

    expect(handleKey(opened.ui, state, key("Digit5")).action).toEqual({ type: "cancel_nomination", seats: [5] })
  })

  it("M opens a text field", () => {
    const opened = press(emptyUi(), speech(), "KeyM")

    expect([opened.ui.pending.type, opened.focus]).toEqual(["note", "pending_text"])
  })

  it("Space moves on", () => {
    expect(press(emptyUi(), speech(), "Space").action).toEqual({ type: "next_speaker" })
  })

  it("V goes to the vote", () => {
    expect(press(emptyUi(), speech(), "KeyV").action).toEqual({ type: "start_vote" })
  })
})

describe("sanctions", () => {
  it.each([["KeyF", "foul"], ["KeyG", "tech"], ["KeyX", "remove_player"]])("%s applies to a number at once", (code, type) => {
    expect(press(emptyUi(), speech(), code, "Digit5").action).toEqual({ type, seats: [5] })
  })

  it("Enter applies to the speaker", () => {
    expect(press(emptyUi(), speech(), "KeyF", "Enter").action).toEqual({ type: "foul", seats: [] })
  })

  it.each([["KeyF", "cancel_foul"], ["KeyG", "cancel_tech"]])("Shift+%s cancels", (code, type) => {
    const state = speech()
    const opened = handleKey(emptyUi(), state, key(code, { shift: true }))

    expect(handleKey(opened.ui, state, key("Digit5")).action).toEqual({ type, seats: [5] })
  })

  it("is available at night", () => {
    expect(press(emptyUi(), night(), "KeyF").ui.pending.type).toBe("foul")
  })

  it("is not available during the deal", () => {
    expect(press(emptyUi(), session([{ type: "assign_roles", seats: [1, 2, 3, 4] }]), "KeyX").ui.pending).toBeNull()
  })
})

describe("the vote", () => {
  const voting = () => session([
    { type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" },
    { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }
  ])

  it("marks voters", () => {
    expect(press(emptyUi(), voting(), "Digit1", "Digit2").ui.marks).toEqual([1, 2])
  })

  it("unmarks a voter pressed again", () => {
    expect(press(emptyUi(), voting(), "Digit1", "Digit1").ui.marks).toEqual([])
  })

  it("Enter sends the marks and clears them", () => {
    const done = press(emptyUi(), voting(), "Digit1", "Enter")

    expect([done.action, done.ui.marks]).toEqual([{ type: "vote_for", seats: [1] }, []])
  })

  it("does not close the vote on the last mark", () => {
    expect(press(emptyUi(), voting(), "Digit1").action).toBeUndefined()
  })
})

describe("the night", () => {
  const donStep = () => session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }, { type: "shoot", seats: [5] }])

  it("a number shoots", () => {
    expect(press(emptyUi(), night(), "Digit5").action).toEqual({ type: "shoot", seats: [5] })
  })

  it("M switches to the miss", () => {
    expect(press(emptyUi(), night(), "KeyM").ui.miss).toBe(true)
  })

  it("a number then records a shooter's target", () => {
    expect(press(emptyUi(), night(), "KeyM", "Digit5").action).toEqual({ type: "miss_shot", seats: [5] })
  })

  it("minus is no shot", () => {
    expect(press(emptyUi(), night(), "KeyM", "Minus").action).toEqual({ type: "miss_shot", miss: "no_shot" })
  })

  it("T is a tactical miss", () => {
    expect(press(emptyUi(), night(), "KeyM", "KeyT").action).toEqual({ type: "miss_shot", miss: "tactical" })
  })

  it("keeps the miss mode between shooters", () => {
    const state = session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }, { type: "miss_shot", miss: "no_shot" }])

    expect(press(emptyUi(), state, "Digit5").action).toEqual({ type: "miss_shot", seats: [5] })
  })

  it("a number checks for the don", () => {
    expect(press(emptyUi(), donStep(), "Digit2").action).toEqual({ type: "don_check", seats: [2] })
  })

  it("Enter skips the don's check", () => {
    expect(press(emptyUi(), donStep(), "Enter").action).toEqual({ type: "don_check", seats: [] })
  })

  it("a number checks for the sheriff", () => {
    const state = session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }])

    expect(press(emptyUi(), state, "Digit3").action).toEqual({ type: "sheriff_check", seats: [3] })
  })
})

describe("the best move and the will", () => {
  const bestMove = () => session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }])
  const leaving = () => session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move" }])

  it("collects numbers", () => {
    expect(press(emptyUi(), bestMove(), "Digit1", "Digit3").ui.marks).toEqual([1, 3])
  })

  it("saves on the third number", () => {
    const done = press(emptyUi(), bestMove(), "Digit1", "Digit3", "Digit4")

    expect([done.action, done.ui.marks]).toEqual([{ type: "best_move", seats: [1, 3, 4] }, []])
  })

  it("Enter with no numbers declines", () => {
    expect(press(emptyUi(), bestMove(), "Enter").action).toEqual({ type: "best_move", seats: [] })
  })

  it("Enter with some numbers waits for the rest", () => {
    expect(press(emptyUi(), bestMove(), "Digit1", "Enter").action).toBeUndefined()
  })

  it("Enter saves a typed will and clears it", () => {
    const done = handleKey({ ...emptyUi(), will: "234к" }, leaving(), key("Enter"))

    expect([done.action, done.ui.will]).toEqual([{ type: "will", text: "234к" }, ""])
  })

  it("Enter on an empty will moves on", () => {
    expect(press(emptyUi(), leaving(), "Enter").action).toEqual({ type: "finish_leaving" })
  })

  it("Space moves on too", () => {
    expect(press(emptyUi(), leaving(), "Space").action).toEqual({ type: "finish_leaving" })
  })

  it("B opens the best move in the leaving speech", () => {
    expect(press(emptyUi(), leaving(), "KeyB", "Digit1", "Digit3", "Digit4").action).toEqual({ type: "best_move", seats: [1, 3, 4] })
  })
})

describe("finishing the game", () => {
  it("Q writes the pending result", () => {
    const state = { ...speech(), pendingResult: "peace_victory" }

    expect(press(emptyUi(), state, "KeyQ").action).toEqual({ type: "finish_game" })
  })

  it("Q does nothing with no result", () => {
    expect(press(emptyUi(), speech(), "KeyQ").action).toBeUndefined()
  })

  it("Shift+D marks a draw", () => {
    expect(handleKey(emptyUi(), speech(), key("KeyD", { shift: true })).action).toEqual({ type: "finish_game", result: "draw" })
  })
})

describe("rolesShown", () => {
  const ui = emptyUi()
  const killed = session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }])

  it.each([
    ["the roles step", replay(players, []), true],
    ["the deal", session([{ type: "assign_roles", seats: [1, 2, 3, 4] }]), true],
    ["the speech", speech(), false],
    ["the night", night(), true],
    ["the best move", killed, false]
  ])("in %s", (_name, state, shown) => {
    expect(rolesShown(state, ui)).toBe(shown)
  })

  it("shows them while H is held", () => {
    expect(rolesShown(speech(), { ...ui, reveal: true })).toBe(true)
  })

  it("shows them once a result is known", () => {
    expect(rolesShown({ ...speech(), pendingResult: "draw" }, ui)).toBe(true)
  })

  it("shows them after the game", () => {
    expect(rolesShown({ ...speech(), stage: "finished" }, ui)).toBe(true)
  })
})

describe("stamp", () => {
  it("gives each event its own id and the group one action id", () => {
    let next = 0
    const stamped = stamp([{ kind: "a" }, { kind: "b" }], () => `id${next += 1}`)

    expect(stamped).toEqual([{ kind: "a", client_id: "id2", action_id: "id1" }, { kind: "b", client_id: "id3", action_id: "id1" }])
  })
})

describe("undoGroup", () => {
  it("takes the last action off with its whole group", () => {
    const events = [{ action_id: "a" }, { action_id: "b" }, { action_id: "b" }]

    expect(undoGroup(events)).toEqual({ actionId: "b", removed: [{ action_id: "b" }, { action_id: "b" }], kept: [{ action_id: "a" }] })
  })

  it("has nothing to do on an empty journal", () => {
    expect(undoGroup([])).toBeNull()
  })
})

describe("canDelete", () => {
  const event = (action_id, kind, day_number = 1) => ({ action_id, kind, day_number })

  it("allows the last action of any kind", () => {
    expect(canDelete([event("a", "note"), event("b", "foul")], "b")).toBe(true)
  })

  it("refuses a middle action other events depend on", () => {
    expect(canDelete([event("a", "foul"), event("b", "note")], "a")).toBe(false)
  })

  it.each(["suspect", "red", "team", "check_request", "note", "will", "best_move"])("allows a middle %s", (kind) => {
    expect(canDelete([event("a", kind), event("b", "foul")], "a")).toBe(true)
  })

  it("refuses when part of a middle group depends", () => {
    expect(canDelete([event("a", "note"), event("a", "foul"), event("b", "note")], "a")).toBe(false)
  })

  it("allows a nomination while its day has no votes", () => {
    expect(canDelete([event("a", "nominate", 2), event("b", "vote", 1)], "a")).toBe(true)
  })

  it("refuses a nomination once its day has votes", () => {
    expect(canDelete([event("a", "nominate", 2), event("b", "vote", 2)], "a")).toBe(false)
  })

  it("does not take another kind of event for a vote", () => {
    expect(canDelete([event("a", "nominate", 2), event("b", "foul", 2)], "a")).toBe(true)
  })
})

describe("restorePlayers", () => {
  const before = [{ seat: 1, role_code: "don" }, { seat: 2, role_code: "peace" }]

  it("brings back the roles the removed event replaced", () => {
    const removed = [{ kind: "roles", metadata: { roles: {}, previous_roles: { 1: "peace", 2: null } } }]

    expect(restorePlayers(before, removed)).toEqual([{ seat: 1, role_code: "peace" }, { seat: 2, role_code: null }])
  })

  it("leaves the players alone for other events", () => {
    expect(restorePlayers(before, [{ kind: "note", metadata: {} }])).toEqual(before)
  })

  it("leaves a seat alone when the event does not name it", () => {
    const removed = [{ kind: "roles", metadata: { roles: {}, previous_roles: { 1: "peace" } } }]

    expect(restorePlayers(before, removed)[1]).toEqual({ seat: 2, role_code: "peace" })
  })
})

describe("keys with no meaning", () => {
  const base = [{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }]
  const toBest = [...base, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }]
  const stages = {
    roles: [],
    deal: [{ type: "assign_roles", seats: [1, 2, 3, 4] }],
    speech: base,
    vote: [...base, { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }],
    night_shot: [...base, { type: "start_vote" }],
    night_miss: [...base, { type: "start_vote" }, { type: "miss_shot", miss: "no_shot" }],
    night_don: [...base, { type: "start_vote" }, { type: "shoot", seats: [5] }],
    night_sheriff: [...base, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }],
    best_move: toBest,
    leaving: [...toBest, { type: "best_move" }]
  }

  it.each(Object.entries(stages))("%s ignores them", (_stage, actions) => {
    const ui = emptyUi()

    expect(handleKey(ui, session(actions), key("KeyJ"))).toEqual({ ui })
  })

  it("the speech ignores other shifted keys", () => {
    const ui = emptyUi()

    expect(handleKey(ui, speech(), key("KeyJ", { shift: true }))).toEqual({ ui })
  })

  it("Ctrl with another key returns the ui", () => {
    const ui = emptyUi()

    expect(handleKey(ui, speech(), key("KeyJ", { ctrl: true }))).toEqual({ ui })
  })

  it("a pending action ignores them", () => {
    const opened = press(emptyUi(), speech(), "KeyS").ui

    expect(handleKey(opened, speech(), key("KeyJ"))).toEqual({ ui: opened })
  })

  it("hints at a number in the leaving speech", () => {
    const state = session(stages.leaving)
    const ui = emptyUi()

    expect(handleKey(ui, state, key("Digit3"))).toEqual({ ui, hint: "choose_action" })
  })

  it("the note is a text mode", () => {
    expect(press(emptyUi(), speech(), "KeyM").ui.pending.mode).toBe("text")
  })

  it("the best move with B keeps waiting under three numbers", () => {
    const state = session(stages.leaving)

    expect(press(emptyUi(), state, "KeyB", "Digit1", "Digit2").action).toBeUndefined()
  })

  it("the note closes on Enter with nothing typed", () => {
    expect(press(emptyUi(), speech(), "KeyN", "Enter").ui.pending).toBeNull()
  })

  it("keeps other seats when one is taken back", () => {
    expect(press(emptyUi(), replay(players, []), "Digit1", "Digit2", "Digit1").ui.marks).toEqual([2])
  })

  it("leaves the miss mode after an answer", () => {
    expect(press(emptyUi(), night(), "KeyM", "KeyT").ui.miss).toBe(false)
  })

  it("leaves the miss mode on Esc", () => {
    expect(press(emptyUi(), night(), "KeyM", "Escape").ui.miss).toBe(false)
  })

  it("ignores Q with Enter in the leaving speech as moving on", () => {
    const state = session(stages.leaving)

    expect(press(emptyUi(), state, "Enter").action).toEqual({ type: "finish_leaving" })
  })

  it("finds nothing in a mistyped digit code", () => {
    expect([digitOf("Digit12"), digitOf("xDigit1"), digitOf("Numpad")]).toEqual([null, null, null])
  })

  it("takes the group of the last event, not the first", () => {
    expect(undoGroup([{ action_id: "a" }, { action_id: "b" }]).actionId).toBe("b")
  })

  it("offers no sanctions on the finished screen", () => {
    expect(handleKey(emptyUi(), { ...speech(), stage: "finished" }, key("KeyQ")).action).toBeUndefined()
  })
})

describe("the last details", () => {
  it("does not finish the game on any other key once a result is known", () => {
    expect(handleKey(emptyUi(), { ...speech(), pendingResult: "draw" }, key("KeyJ")).action).toBeUndefined()
  })

  it("finds the last group among several", () => {
    expect(undoGroup([{ action_id: "a" }, { action_id: "b" }, { action_id: "c" }]).actionId).toBe("c")
  })
})

describe("the player filter after the game", () => {
  const over = () => session([{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal" }, { type: "finish_game", result: "draw" }])

  it("a number picks the player", () => {
    expect(press(emptyUi(), over(), "Digit4").ui.filter).toBe(4)
  })

  it("0 picks seat 10", () => {
    expect(press(emptyUi(), over(), "Digit0").ui.filter).toBe(10)
  })

  it("Esc drops the filter", () => {
    expect(press(emptyUi(), over(), "Digit4", "Escape").ui.filter).toBeNull()
  })

  it("has no filter during the game", () => {
    expect(press(emptyUi(), speech(), "Digit4").ui.filter).toBeNull()
  })

  it("starts with no filter", () => {
    expect(emptyUi().filter).toBeNull()
  })
})
