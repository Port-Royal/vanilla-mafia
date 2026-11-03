import { describe, expect, it } from "vitest"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"
import { emptyUi } from "../../../app/javascript/live_protocol/console.js"
import { renderScreen, willPreview } from "../../../app/javascript/live_protocol/screen.js"

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

describe("the vote", () => {
  const voteTexts = new Proxy({}, {
    get: (_target, name) => (name === "vote" ? new Proxy({}, { get: (_t, inner) => (inner === "not_voted" ? "NV %{seats}" : `vote.${String(inner)}`) }) : texts[name])
  })
  const candidates = [{ type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "next_speaker" }, { type: "nominate", seats: [7] }]
  const voting = (...actions) => stateAfter([...dayActions, ...candidates, { type: "start_vote" }, ...actions])
  const notVoted = (html) => /<div class="lp-not-voted">([^<]*)<\/div>/.exec(html)?.[1]

  it("lists everybody before the first vote", () => {
    expect(notVoted(renderScreen(voting(), emptyUi(), voteTexts))).toBe("NV 1, 2, 3, 4, 5, 6, 7, 8, 9, 10")
  })

  it("leaves out the players who voted", () => {
    expect(notVoted(renderScreen(voting({ type: "vote_for", seats: [1, 2, 3] }), emptyUi(), voteTexts))).toBe("NV 4, 5, 6, 7, 8, 9, 10")
  })

  it("leaves out the players marked now", () => {
    expect(notVoted(renderScreen(voting(), { ...emptyUi(), marks: [2, 4] }, voteTexts))).toBe("NV 1, 3, 5, 6, 7, 8, 9, 10")
  })

  it("leaves out the players who left the table", () => {
    const state = voting({ type: "vote_for", seats: [1, 2, 3, 4, 5, 6] }, { type: "remove_player", seats: [10] })

    expect(notVoted(renderScreen(state, emptyUi(), voteTexts))).toBe("NV 7, 8, 9")
  })

  it("shows nothing once everybody is marked", () => {
    expect(renderScreen(voting(), { ...emptyUi(), marks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }, voteTexts)).not.toContain("lp-not-voted")
  })
})

describe("seat numbers in the side panel", () => {
  const badge = (seat, color) => `<span class="lp-sn lp-sn--${color}">${seat}</span>`
  const revealed = { ...emptyUi(), reveal: true }
  const nominated = () => stateAfter([...dayActions, { type: "nominate", seats: [5] }, { type: "suspect", seats: [2] }])
  const leaving = [...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move" }]
  const willed = () => stateAfter([...leaving, { type: "will", text: "2ш 3ч 6к план" }])

  it("are plain text while the roles are hidden", () => {
    expect(renderScreen(nominated(), emptyUi(), texts)).not.toContain("lp-sn")
  })

  it("put the actor on the black background of the don", () => {
    expect(renderScreen(nominated(), revealed, texts)).toContain(`<span class="lp-a">${badge(1, "black")}</span>`)
  })

  it("put a peaceful target on the red background", () => {
    expect(renderScreen(nominated(), revealed, texts)).toContain(`log.kind_nominate ${badge(5, "red")}`)
  })

  it("put the sheriff on the yellow background", () => {
    expect(renderScreen(nominated(), revealed, texts)).toContain(`log.kind_suspect ${badge(2, "yellow")}`)
  })

  it("colour the seats of a will in the log", () => {
    expect(renderScreen(willed(), revealed, texts)).toContain(`leaving.black: ${badge(3, "black")}; leaving.sheriff: ${badge(2, "yellow")}`)
  })

  it("keep a will plain while the roles are hidden", () => {
    expect(renderScreen(willed(), emptyUi(), texts)).toContain("leaving.red: 6; leaving.black: 3; leaving.sheriff: 2; leaving.plan: план")
  })

  it("still escape the plan of a will", () => {
    expect(renderScreen(stateAfter([...leaving, { type: "will", text: "2ш <i>x</i>" }]), revealed, texts)).toContain("&lt;i&gt;x&lt;/i&gt;")
  })

  it("colour the seats on the sheet", () => {
    expect(renderScreen(willed(), { ...revealed, tab: "sheet" }, texts)).toContain(`<td>${badge(5, "red")}</td>`)
  })

  it("colour the voters on the sheet", () => {
    const voted = stateAfter([...dayActions, { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }, { type: "vote_for", seats: [1, 2] }])

    expect(renderScreen(voted, { ...revealed, tab: "sheet" }, texts)).toContain(`<td>${badge(1, "black")}, ${badge(2, "yellow")}</td>`)
  })

  it("keep the sheet plain while the roles are hidden", () => {
    expect(renderScreen(willed(), { ...emptyUi(), tab: "sheet" }, texts)).not.toContain("lp-sn")
  })
})

describe("the sheet", () => {
  const TEMPLATES = { "sheet.claimed_sheriff": "шериф %{seat}", "strip.night": "Н%{number}", "strip.day": "Д%{number}" }
  const sheetTexts = new Proxy({}, {
    get: (_target, name) => (name === "seats" ? "" : new Proxy({}, { get: (_t, inner) => TEMPLATES[`${String(name)}.${String(inner)}`] ?? `${String(name)}.${String(inner)}` }))
  })
  const badge = (seat, color) => `<span class="lp-sn lp-sn--${color}">${seat}</span>`
  const start = (deal = {}) => [{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal", ...deal }]
  const sheetOf = (actions, ui = { ...emptyUi(), reveal: true }) => renderScreen(stateAfter(actions), { ...ui, tab: "sheet" }, sheetTexts)
  const missAll = [{ type: "miss_shot", seats: [7] }, { type: "miss_shot", miss: "no_shot" }, { type: "miss_shot", miss: "tactical" }]
  const leaving = [...start(), { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }, { type: "sheriff_check" }]

  it("lists the deal with the claimed sheriff on his colour", () => {
    expect(sheetOf(start({ mode: "static", seats: [5], text: "<план>" }))).toContain(`<h4>sheet.deal</h4>deal.static; шериф ${badge(5, "red")}; &lt;план&gt;</div>`)
  })

  it("says the deal was empty", () => {
    expect(sheetOf(start())).toContain("<h4>sheet.deal</h4>sheet.nothing</div>")
  })

  it("hides the deal by day", () => {
    expect(sheetOf(start({ mode: "static" }), emptyUi())).toContain("<h4>sheet.deal</h4>log.hidden</div>")
  })

  it("lists the misses with the shooters on their colours", () => {
    expect(sheetOf([...start(), { type: "start_vote" }, ...missAll])).toContain(
      `<div>Н1: ${badge(1, "black")} → ${badge(7, "red")}</div><div>Н1: ${badge(3, "black")} → night.no_shot</div><div>Н1: ${badge(4, "black")} → night.tactical</div>`
    )
  })

  it("lists the shots on their colours", () => {
    expect(sheetOf(leaving)).toContain(`<h4>sheet.shots</h4><table><tr><td>${badge(5, "red")}</td></tr></table></div>`)
  })

  it("lists the checks with the checked seat on its colour", () => {
    expect(sheetOf(leaving)).toContain(
      `<h4>sheet.checks</h4><table><tr><td>sheet.night</td><td>sheet.don</td><td>sheet.sheriff</td></tr><tr><td>1</td><td>${badge(2, "yellow")} sheet.check_sheriff</td><td>—</td></tr></table></div>`
    )
  })

  it("says there were no checks yet", () => {
    expect(sheetOf(start())).toContain("<h4>sheet.checks</h4>sheet.nothing</div>")
  })

  it("hides the checks by day", () => {
    expect(sheetOf(start(), emptyUi())).toContain("<h4>sheet.checks</h4>log.hidden</div>")
  })

  it("lists a round of the zero day with its outcome", () => {
    const html = sheetOf([...start(), { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }, { type: "vote_for", seats: [1, 2, 3, 4, 7, 8] }])

    expect(html).toContain(`<h4>strip.zero, sheet.round_main</h4><table><tr><td>sheet.candidate</td><td>sheet.count</td><td>sheet.voters</td></tr><tr><td>${badge(5, "red")}</td><td>6</td>`)
    expect(html).toContain("</table><div>sheet.outcome_leave</div></div>")
  })

  it("names why nobody left", () => {
    const shares = [[1, 2], [3, 4], [5, 6], [7, 8]].map((seats) => ({ type: "vote_for", seats }))
    const nominations = [1, 2, 3, 4, 5].flatMap((seat, index) => [{ type: "set_speaker", seats: [index + 1] }, { type: "nominate", seats: [seat] }])

    expect(sheetOf([...start(), ...nominations, { type: "start_vote" }, ...shares, ...shares])).toContain("<div>sheet.outcome_none: sheet.reason_five_or_ten_zero</div>")
  })

  it("leaves the outcome out of a round in progress", () => {
    const html = sheetOf([...start(), { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "next_speaker" }, { type: "nominate", seats: [7] }, { type: "start_vote" }, { type: "vote_for", seats: [1] }])

    expect(html).toContain(`<tr><td>${badge(5, "red")}</td><td>1</td><td>${badge(1, "black")}</td></tr></table></div>`)
  })

  it("titles a round of a later day by its number", () => {
    const later = [...start(), { type: "start_vote" }, ...missAll, { type: "don_check" }, { type: "sheriff_check" }, { type: "nominate", seats: [5] }, { type: "start_vote" }]

    expect(sheetOf(later)).toContain("<h4>Д1, sheet.round_main</h4>")
  })

  it("lists a will and a best move on their colours", () => {
    expect(sheetOf([...leaving, { type: "best_move", seats: [1, 2, 3] }, { type: "will", text: "4ч" }])).toContain(
      `<h4>sheet.wills</h4><div><b>${badge(5, "red")}</b> leaving.black: ${badge(4, "black")}</div><div><b>${badge(5, "red")}</b> ${badge(1, "black")}, ${badge(2, "yellow")}, ${badge(3, "black")}</div></div>`
    )
  })

  it("marks a best move with no points", () => {
    const twoGone = [...start(), { type: "remove_player", seats: [9] }, { type: "remove_player", seats: [10] }, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move", seats: [1, 3, 4] }]

    expect(sheetOf(twoGone)).toContain(`${badge(4, "black")} (sheet.no_points)</div>`)
  })

  it("puts one will and one best move after another", () => {
    const html = sheetOf([
      ...leaving, { type: "best_move", seats: [1, 2, 3] }, { type: "will", text: "4ч" }, { type: "finish_leaving" },
      { type: "nominate", seats: [6] }, { type: "start_vote" }, { type: "best_move", seats: [7, 8, 9] }, { type: "will", text: "3ч" }
    ])

    expect(html).toContain(`${badge(4, "black")}</div><div><b>${badge(6, "red")}</b> leaving.black: ${badge(3, "black")}</div><div><b>`)
    expect(html).toContain(`${badge(3, "black")}</div><div><b>${badge(6, "red")}</b> ${badge(7, "red")}`)
  })

  it("puts one round after another", () => {
    const tied = [...start(), { type: "nominate", seats: [5] }, { type: "next_speaker" }, { type: "nominate", seats: [6] }, { type: "start_vote" }, { type: "vote_for", seats: [1, 2, 3, 4, 7] }, { type: "vote_for", seats: [1] }]

    expect(sheetOf(tied)).toContain("<div>sheet.outcome_repeat</div></div><div><h4>strip.zero, sheet.round_repeat</h4>")
  })

  it("adds nothing after the shots while the misses are hidden", () => {
    expect(sheetOf(leaving, emptyUi())).toContain(`<h4>sheet.shots</h4><table><tr><td>5</td></tr></table></div>`)
  })

  it("adds nothing between the deal and the shots without the hint", () => {
    expect(sheetOf(start())).toMatch(/<h4>sheet.deal<\/h4>sheet.nothing<\/div>\s*<div><h4>sheet.shots/)
  })

  it("says there are no wills", () => {
    expect(sheetOf(start())).toContain("<h4>sheet.wills</h4>sheet.nothing</div>")
  })

  it("gives the sheriff bonus hint", () => {
    expect(sheetOf([...start({ mode: "dynamic" }), { type: "start_vote" }, { type: "shoot", seats: [2] }])).toContain('<div class="lp-good">sheet.sheriff_bonus</div>')
  })

  it("gives no hint otherwise", () => {
    expect(sheetOf(start())).not.toContain("lp-good")
  })
})

describe("the log entries", () => {
  const revealed = { ...emptyUi(), reveal: true }
  const entryOf = (state, ui = revealed) => renderScreen(state, ui, texts)

  it("join only the parts an entry has", () => {
    expect(entryOf(stateAfter(dayActions))).toContain('<span class="lp-a"></span><span>log.kind_roles</span>')
  })

  it("hide the actor of a secret entry by day", () => {
    const night = stateAfter([...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check", seats: [2] }, { type: "sheriff_check" }])

    expect(entryOf(night, emptyUi())).toContain('<span class="lp-a"></span><span>log.hidden</span>')
  })

  it("list only the sheriff of a will that names nobody else", () => {
    const willed = stateAfter([...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move" }, { type: "will", text: "2ш" }])

    expect(entryOf(willed)).toContain('<span>log.kind_will leaving.sheriff: <span class="lp-sn lp-sn--yellow">2</span></span>')
  })

  it("keep a seat with nobody in it plain", () => {
    const willed = stateAfter([...dayActions, { type: "start_vote" }, { type: "shoot", seats: [5] }, { type: "don_check" }, { type: "sheriff_check" }, { type: "best_move" }, { type: "will", text: "10к" }])
    willed.players[10] = undefined

    expect(entryOf(willed)).toContain("<span>log.kind_will leaving.red: 10</span>")
  })
})

describe("the will preview", () => {
  it("is plain text", () => {
    expect(willPreview("2ш план", texts)).toBe("leaving.sheriff: 2; leaving.plan: план")
  })

  it("is empty for an empty will", () => {
    expect(willPreview("", texts)).toBe("")
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
