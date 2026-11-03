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

describe("the connection status", () => {
  it.each(["saved", "saving", "offline", "rejected"])("shows %s", (status) => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts, "", status)).toContain(`connection.${status}`)
  })

  it("marks the problem states", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts, "", "offline")).toContain("lp-status--bad")
  })

  it("does not mark saved as a problem", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts, "", "saved")).not.toContain("lp-status--bad")
  })
})

describe("the tabs", () => {
  const checked = [...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }, { type: "sheriff_check", seats: [3] }, { type: "best_move" }, { type: "will", text: "<u>план</u>" }, { type: "finish_leaving" }]

  it("offers both tabs", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts).match(/data-tab="/g)).toHaveLength(2)
  })

  it("names the scrolling panels after the seat list and the open tab", () => {
    expect(renderScreen(stateAfter(dayActions), { ...emptyUi(), tab: "sheet" }, texts).match(/data-scroll="[a-z]+"/g)).toEqual(['data-scroll="seats"', 'data-scroll="sheet"'])
  })

  it("shows the record by default", () => {
    expect(renderScreen(stateAfter(dayActions), emptyUi(), texts)).toContain('class="lp-log"')
  })

  it("shows the sheet when chosen", () => {
    expect(renderScreen(stateAfter(dayActions), { ...emptyUi(), tab: "sheet" }, texts)).toContain('class="lp-sheet"')
  })

  it("keeps secrets out of the sheet by day", () => {
    const html = renderScreen(stateAfter(checked), { ...emptyUi(), tab: "sheet" }, texts)

    expect([html.includes("тайный план"), html.includes("sheet.check_black")]).toEqual([false, false])
  })

  it("shows them while H is held", () => {
    const html = renderScreen(stateAfter(checked), { ...emptyUi(), tab: "sheet", reveal: true }, texts)

    expect([html.includes("тайный план"), html.includes("sheet.check_black")]).toEqual([true, true])
  })

  it("escapes a will in the sheet", () => {
    expect(renderScreen(stateAfter(checked), { ...emptyUi(), tab: "sheet" }, texts)).toContain("&lt;u&gt;план&lt;/u&gt;")
  })
})

describe("the player filter", () => {
  const over = [...dayActions, { type: "suspect", seats: [4] }, { type: "finish_game", result: "draw" }]

  it("shows the two blocks for the chosen player", () => {
    const html = renderScreen(stateAfter(over), { ...emptyUi(), filter: 4 }, texts)

    expect([html.includes("filter.actions"), html.includes("filter.received")]).toEqual([true, true])
  })

  it("shows the player's role and outcome", () => {
    const html = renderScreen(stateAfter(over), { ...emptyUi(), filter: 4 }, texts)

    expect([html.includes('data-role="mafia"'), html.includes("filter.outcome_draw")]).toEqual([true, true])
  })

  it("leaves out records about others", () => {
    const html = renderScreen(stateAfter([...over.slice(0, -1), { type: "note", text: "чужая заметка" }, over.at(-1)]), { ...emptyUi(), filter: 4 }, texts)

    expect(html).not.toContain("чужая заметка")
  })

  it("groups the records by stage", () => {
    expect(renderScreen(stateAfter(over), { ...emptyUi(), filter: 4 }, texts)).toContain("strip.zero")
  })

  it("offers the filter hint on the finished screen", () => {
    expect(renderScreen(stateAfter(over), emptyUi(), texts)).toContain("filter.hint")
  })
})

describe("the deal sheriff highlight", () => {
  const dealUi = { ...emptyUi(), deal: { mode: "static", sheriff: 10, text: "" } }
  const picked = (html) => {
    const root = document.createElement("div")
    root.innerHTML = html
    return [...root.querySelectorAll(".lp-seat--picked")].map((seat) => Number(seat.dataset.seat))
  }

  it("marks the chosen sheriff during the deal", () => {
    expect(picked(renderScreen(stateAfter([dayActions[0]]), dealUi, texts))).toEqual([10])
  })

  it("marks no seat once the deal is finished", () => {
    expect(picked(renderScreen(stateAfter(dayActions), dealUi, texts))).toEqual([])
  })

  it("still marks the seats picked in the current stage", () => {
    expect(picked(renderScreen(stateAfter(dayActions), { ...dealUi, marks: [3] }, texts))).toEqual([3])
  })
})
