import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"
import { emptyUi } from "../../../app/javascript/live_protocol/console.js"
import { renderScreen } from "../../../app/javascript/live_protocol/screen.js"

const players = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((seat) => ({ seat, name: seat === 7 ? "<b>Зло</b>" : `И${seat}`, role_code: null }))
const texts = new Proxy({}, { get: (_target, name) => (name === "seats" ? "" : new Proxy({}, { get: (_t, inner) => `${String(name)}.${String(inner)}` })) })

function stateAfter(actions) {
  const events = []
  actions.forEach((action) => events.push(...decide(replay(players, events), action).events))
  return replay(players, events)
}

const dayActions = [{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal", mode: "static", seats: [5], text: "тайный план" }]
const roleBadges = (html) => (html.match(/data-role="[a-z]+"/g) || [])

describe("renderScreen", () => {
  it("has no role in the markup by day", () => {
    expect(roleBadges(renderScreen(stateAfter(dayActions), emptyUi(), texts))).toEqual([])
  })

  it("does not mention the role codes by day", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts)).not.toMatch(/"(don|sheriff|mafia)"/)
  })

  it("shows the roles while H is held", () => {
    expect(roleBadges(renderScreen(stateAfter(dayActions), { ...emptyUi(), reveal: true }, texts))).toContain('data-role="don"')
  })

  it("keeps the deal out of the log by day", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts)).not.toContain("тайный план")
  })

  it("keeps a check out of the log by day", () => {
    const html = renderScreen(stateAfter([...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }, { type: "sheriff_check" }, { type: "best_move" }, { type: "finish_leaving" }]), emptyUi(), texts)

    expect(html).not.toContain("log.kind_don_check")
  })

  it("shows the deal in the log while H is held", () => {
    expect(renderScreen(stateAfter(dayActions), { ...emptyUi(), reveal: true }, texts)).toContain("тайный план")
  })

  it("escapes player names", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts)).toContain("&lt;b&gt;Зло&lt;/b&gt;")
  })

  it("escapes what the judge typed", () => {
    const html = renderScreen(stateAfter([...dayActions, { type: "note", text: "<i>x</i>" }]), emptyUi(), texts)

    expect(html).toContain("&lt;i&gt;x&lt;/i&gt;")
  })

  it("labels every button with its key", () => {
    const html = renderScreen(stateAfter(dayActions), emptyUi(), texts)
    const buttons = html.match(/<button[^>]*data-code=[^>]*>/g)

    expect(buttons.length).toBeGreaterThan(5)
    expect(html.match(/class="lp-key"/g).length).toBeGreaterThanOrEqual(buttons.length)
  })

  it("renders all ten seats", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts).match(/data-seat="\d+"/g)).toHaveLength(10)
  })

  it.each([
    ["roles", []],
    ["deal", [{ type: "assign_roles", seats: [1, 2, 3, 4] }]],
    ["speech", dayActions],
    ["night", [...dayActions, { type: "start_vote" }]],
    ["vote", [...dayActions, { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }]],
    ["best move", [...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }]],
    ["leaving", [...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move" }]],
    ["finished", [...dayActions, { type: "finish_game", result: "draw" }]]
  ])("renders the %s stage", (_name, actions) => {
    expect(renderScreen(stateAfter(actions), emptyUi(), texts)).toContain('id="lp-work"')
  })

  it("marks the speaker", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts)).toMatch(/lp-seat--speaking[^>]*data-seat="1"/)
  })

  it("shows the will parse as it is typed", () => {
    const state = stateAfter([...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move" }])

    expect(renderScreen(state, { ...emptyUi(), will: "23к" }, texts)).toContain("2, 3")
  })

  it("warns that a vote is cancelled", () => {
    const html = renderScreen(stateAfter([...dayActions, { type: "remove_player", seats: [9] }]), emptyUi(), texts)

    expect(html).toContain("speech.no_vote")
  })
})
