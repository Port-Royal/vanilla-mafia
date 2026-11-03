// Builds the console's markup from the state. Secrets that must stay hidden are left out of the
// markup entirely rather than hidden with styles.
import { rolesShown } from "live_protocol/console"
import { buildSheet } from "live_protocol/game_sheet"
import { playerEvents } from "live_protocol/player_events"
import { parseWill } from "live_protocol/will_parser"

const SECRET_KINDS = ["roles", "deal", "don_check", "sheriff_check", "miss_shot"]
const ROLE_LETTERS = { don: "don", sheriff: "sheriff", mafia: "mafia", peace: "peace" }
const SEATS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]))
const fill = (template, values) => Object.entries(values).reduce((text, [name, value]) => text.replaceAll(`%{${name}}`, escapeHtml(value)), template)
const nameOf = (state, seat) => escapeHtml(state.players[seat]?.name)

function button(code, keyLabel, label, { shift = false, big = false, on = false } = {}) {
  const classes = ["lp-act", big ? "lp-act--big" : "", on ? "lp-act--on" : ""].filter(Boolean).join(" ")
  return `<button type="button" class="${classes}" data-code="${code}" data-shift="${shift}"><span class="lp-key">${keyLabel}</span>${escapeHtml(label)}</button>`
}

function heading(eyebrow, title) {
  return `<div><div class="lp-eyebrow">${escapeHtml(eyebrow)}</div><p class="lp-headline">${title}</p></div>`
}

const prompt = (title, seats, hint) => `<div class="lp-prompt"><b>${escapeHtml(title)}</b><div class="lp-picks">${seats.join(", ") || "…"}</div><small>${escapeHtml(hint)}</small></div>`

export function willPreview(raw, texts) {
  const { red, black, sheriff, plan } = parseWill(raw)
  const parts = []
  if (red.length) parts.push(`${texts.leaving.red}: ${red.join(", ")}`)
  if (black.length) parts.push(`${texts.leaving.black}: ${black.join(", ")}`)
  if (sheriff.length) parts.push(`${texts.leaving.sheriff}: ${sheriff.join(", ")}`)
  if (plan) parts.push(`${texts.leaving.plan}: ${plan}`)
  return parts.join("; ")
}

function seatMark(state, ui, seat) {
  return ui.marks.includes(seat) || ui.pending?.seats.includes(seat) || ui.deal.sheriff === seat
}

function seatHtml(state, ui, texts, seat) {
  const player = state.players[seat]
  if (!player) return `<div class="lp-seat lp-seat--empty" data-seat="${seat}"><span class="lp-n">${seat}</span></div>`

  const classes = ["lp-seat"]
  if (state.speaker === seat || state.leaving[0] === seat) classes.push("lp-seat--speaking")
  if (seatMark(state, ui, seat)) classes.push("lp-seat--picked")
  if (player.out) classes.push("lp-seat--out")

  const role = rolesShown(state, ui) && ROLE_LETTERS[player.role]
    ? `<span class="lp-role lp-role--${player.role}" data-role="${player.role}">${escapeHtml(texts.roles[player.role])}</span>`
    : '<span class="lp-role"></span>'
  const dots = (count, total, kind) => Array.from({ length: total }, (_unused, index) => (index < count
    ? `<span class="lp-dot lp-dot--${kind} lp-dot--on" data-cancel="cancel_${kind}" data-cancel-seat="${seat}"></span>`
    : `<span class="lp-dot lp-dot--${kind}"></span>`)).join("")
  const status = player.out ? texts.out[player.outReason] : ""

  return `<button type="button" class="${classes.join(" ")}" data-seat="${seat}">
    <span class="lp-n">${seat}</span>
    <span class="lp-name">${nameOf(state, seat)}<span class="lp-sub">${escapeHtml(status)}</span></span>
    ${role}<span class="lp-dots">${dots(player.fouls, 4, "foul")}</span><span class="lp-dots">${dots(player.tech, 2, "tech")}</span>
  </button>`
}

function stripHtml(state, texts) {
  const steps = [["deal", texts.strip.deal], ["zero", texts.strip.zero]]
  for (let number = 1; number <= Math.max(state.nights, state.day) + 1; number += 1) {
    steps.push([`night${number}`, fill(texts.strip.night, { number })], [`day${number}`, fill(texts.strip.day, { number })])
  }
  const current = currentStep(state)
  return steps.map(([id, label]) => `<span class="lp-step${id === current ? " lp-step--now" : ""}">${escapeHtml(label)}</span>`).join("")
}

function currentStep(state) {
  if (["roles", "deal"].includes(state.stage)) return "deal"
  if (state.stage.startsWith("night")) return `night${state.nights}`
  return state.day === 0 ? "zero" : `day${state.day}`
}

function sanctionsHtml(texts) {
  return `<div class="lp-group"><h3>${escapeHtml(texts.actions.sanctions)}</h3><div class="lp-actions">
    ${button("KeyF", "F", texts.actions.foul)}${button("KeyG", "G", texts.actions.tech)}${button("KeyX", "X", texts.actions.remove)}
    ${button("KeyF", "⇧F", texts.actions.cancel_foul, { shift: true })}${button("KeyG", "⇧G", texts.actions.cancel_tech, { shift: true })}
  </div></div>`
}

function pendingHtml(state, ui, texts) {
  const { pending } = ui
  if (!pending) return ""
  const title = texts.pending[pending.type]
  if (pending.mode === "text") {
    return `<div class="lp-prompt"><b>${escapeHtml(title)}</b><input id="lp-pending-text" class="lp-input" autocomplete="off"><small>${escapeHtml(texts.pending.text_hint)}</small></div>`
  }
  return prompt(title, pending.seats, texts.pending[`${pending.mode}_hint`])
}

const finishHtml = (state, texts) => {
  const result = state.pendingResult
    ? `<div class="lp-good">${escapeHtml(texts.results[state.pendingResult])}</div>${button("KeyQ", "Q", texts.actions.finish, { big: true })}`
    : ""
  const draw = state.drawSuggested ? `<div class="lp-warn">${escapeHtml(texts.finish.draw_suggested)}</div>` : ""
  return `${result}${draw}${button("KeyD", "⇧D", texts.actions.draw, { shift: true })}`
}

const STAGE_VIEWS = {
  roles(state, ui, texts) {
    return `${heading(texts.roles.eyebrow, escapeHtml(texts.roles.title))}
      ${prompt(texts.roles.prompt, ui.marks, texts.roles.hint)}
      <div class="lp-bar">${button("Enter", "Enter", texts.roles.go, { big: true })}</div>`
  },
  deal(state, ui, texts) {
    return `${heading(texts.deal.eyebrow, escapeHtml(texts.deal.title))}
      <div class="lp-actions">${button("KeyS", "S", texts.deal.static, { on: ui.deal.mode === "static" })}${button("KeyD", "D", texts.deal.dynamic, { on: ui.deal.mode === "dynamic" })}</div>
      <div class="lp-group"><h3>${escapeHtml(texts.deal.sheriff)}</h3><div>${ui.deal.sheriff ? `${ui.deal.sheriff} ${nameOf(state, ui.deal.sheriff)}` : escapeHtml(texts.deal.sheriff_hint)}</div></div>
      <div class="lp-prompt"><label for="lp-deal-text"><b>${escapeHtml(texts.deal.text)}</b></label><input id="lp-deal-text" class="lp-input" value="${escapeHtml(ui.deal.text)}" autocomplete="off"><small>${escapeHtml(texts.deal.text_hint)}</small></div>
      <div class="lp-bar">${button("Enter", "Enter", texts.deal.go, { big: true })}</div>`
  },
  speech(state, ui, texts) {
    const candidates = state.candidates.map((seat) => `<button type="button" class="lp-chip" data-cancel="cancel_nomination" data-cancel-seat="${seat}">${seat} ×</button>`).join("")
    return `${heading(texts.speech.eyebrow, `<span class="lp-num">${state.speaker}</span> ${nameOf(state, state.speaker)}`)}
      ${state.noVoteDay === state.day ? `<div class="lp-warn">${escapeHtml(texts.speech.no_vote)}</div>` : ""}
      ${pendingHtml(state, ui, texts)}
      <div class="lp-actions">
        ${button("KeyS", "S", texts.actions.suspect)}${button("KeyR", "R", texts.actions.red)}${button("KeyT", "T", texts.actions.team)}
        ${button("KeyC", "C", texts.actions.check_request)}${button("KeyN", "N", texts.actions.nominate)}${button("KeyM", "M", texts.actions.note)}
      </div>
      <div class="lp-group"><h3>${escapeHtml(texts.speech.candidates)}</h3><div class="lp-chips">${candidates || escapeHtml(texts.speech.no_candidates)}</div></div>
      ${sanctionsHtml(texts)}
      <div class="lp-bar">${button("Space", "Space", texts.speech.next, { big: true })}${button("KeyV", "V", texts.speech.to_vote)}${finishHtml(state, texts)}</div>`
  },
  vote(state, ui, texts) {
    const { round } = state
    const lift = round.type === "lift"
    const title = lift ? fill(texts.vote.lift, { seats: round.candidates.join(", ") }) : `<span class="lp-num">${round.candidates[round.index]}</span> ${nameOf(state, round.candidates[round.index])}`
    const rows = round.candidates.map((seat, index) => {
      const voters = round.votes[seat] ?? []
      return `<div class="lp-vote${!lift && index === round.index ? " lp-vote--now" : ""}"><span>${seat} ${nameOf(state, seat)}</span><span class="lp-cnt">${voters.length}</span><span>${voters.join(", ")}</span></div>`
    }).join("")
    return `${heading(texts.vote[round.type], title)}
      ${pendingHtml(state, ui, texts)}
      <div class="lp-group">${rows}</div>
      ${prompt(texts.vote.marks, ui.marks, texts.vote.hint)}
      ${sanctionsHtml(texts)}
      <div class="lp-bar">${button("Enter", "Enter", texts.vote.go, { big: true })}${finishHtml(state, texts)}</div>`
  },
  night_shot(state, ui, texts) {
    if (ui.miss) return STAGE_VIEWS.night_miss(state, ui, texts)
    return `${heading(texts.night.shot_eyebrow, escapeHtml(texts.night.shot))}
      ${pendingHtml(state, ui, texts)}
      <div class="lp-bar">${button("KeyM", "M", texts.night.miss, { big: true })}</div>${sanctionsHtml(texts)}${finishHtml(state, texts)}`
  },
  night_miss(state, ui, texts) {
    const shooter = Object.keys(state.players).map(Number).find((seat) => !state.players[seat].out && ["don", "mafia"].includes(state.players[seat].role) && !state.missed.includes(seat))
    return `${heading(texts.night.miss_eyebrow, fill(texts.night.miss_who, { seat: shooter }))}
      ${pendingHtml(state, ui, texts)}
      <div class="lp-actions">${button("Minus", "−", texts.night.no_shot)}${button("KeyT", "T", texts.night.tactical)}</div>${sanctionsHtml(texts)}`
  },
  night_don: (state, ui, texts) => checkView(state, ui, texts, "don"),
  night_sheriff: (state, ui, texts) => checkView(state, ui, texts, "sheriff"),
  best_move(state, ui, texts) {
    return `${heading(texts.best.eyebrow, `<span class="lp-num">${state.leaving[0]}</span> ${nameOf(state, state.leaving[0])}`)}
      ${state.zeroDepartures.length >= 2 ? `<div class="lp-warn">${escapeHtml(texts.best.no_points)}</div>` : ""}
      ${pendingHtml(state, ui, texts)}
      ${prompt(texts.best.prompt, ui.marks, texts.best.hint)}
      <div class="lp-bar">${button("Enter", "Enter", texts.best.skip)}</div>${sanctionsHtml(texts)}`
  },
  leaving(state, ui, texts) {
    if (state.leaving.length === 0) return `${heading(texts.finish.eyebrow, escapeHtml(texts.results[state.pendingResult]))}<div class="lp-bar">${finishHtml(state, texts)}</div>`
    return `${heading(texts.leaving.eyebrow, `<span class="lp-num">${state.leaving[0]}</span> ${nameOf(state, state.leaving[0])}`)}
      ${pendingHtml(state, ui, texts)}
      <div class="lp-prompt"><label for="lp-will"><b>${escapeHtml(texts.leaving.will)}</b></label><input id="lp-will" class="lp-input" value="${escapeHtml(ui.will)}" autocomplete="off">
        <div id="lp-will-preview" class="lp-preview">${escapeHtml(willPreview(ui.will, texts))}</div><small>${escapeHtml(texts.leaving.hint)}</small></div>
      <div class="lp-actions">${button("KeyB", "B", texts.actions.best_move)}</div>
      ${sanctionsHtml(texts)}
      <div class="lp-bar">${button("Enter", "Enter", texts.leaving.next, { big: true })}${finishHtml(state, texts)}</div>`
  },
  finished(state, ui, texts) {
    return `${heading(texts.finish.eyebrow, escapeHtml(texts.finish.done))}<div class="lp-group">${escapeHtml(texts.filter.hint)}</div>`
  }
}

function checkView(state, ui, texts, role) {
  const seat = Object.keys(state.players).map(Number).find((candidate) => state.players[candidate].role === role && !state.players[candidate].out)
  return `${heading(texts.night[`${role}_eyebrow`], fill(texts.night.check_who, { seat }))}
    ${pendingHtml(state, ui, texts)}
    <div class="lp-bar">${button("Enter", "Enter", texts.night.skip)}</div>${sanctionsHtml(texts)}`
}

function logEntry(state, ui, texts, event) {
  const shown = rolesShown(state, ui) || !SECRET_KINDS.includes(event.kind)
  const body = shown
    ? [texts.log[`kind_${event.kind}`], event.target_seats.join(", "), event.kind === "will" ? willPreview(event.text, texts) : event.text].filter(Boolean).join(" ")
    : texts.log.hidden
  const actor = shown && event.actor_seat ? event.actor_seat : ""
  return `<div class="lp-entry"><span class="lp-a">${actor}</span><span>${escapeHtml(body)}</span><button type="button" class="lp-x" data-delete="${escapeHtml(event.action_id)}" aria-label="${escapeHtml(texts.log.delete)}">×</button></div>`
}

const seatsList = (seats) => seats.join(", ")

function table(rows) {
  return `<table>${rows.map((cells) => `<tr>${cells.map((cell) => `<td>${escapeHtml(cell)}</td>`).join("")}</tr>`).join("")}</table>`
}

function section(title, body) {
  return `<div><h4>${escapeHtml(title)}</h4>${body}</div>`
}

function dealSection(deal, texts) {
  if (!deal) return section(texts.sheet.deal, escapeHtml(texts.log.hidden))
  const parts = [
    deal.mode ? texts.deal[deal.mode] : "",
    deal.sheriff ? fill(texts.sheet.claimed_sheriff, { seat: deal.sheriff }) : "",
    deal.text
  ].filter(Boolean)
  return section(texts.sheet.deal, escapeHtml(parts.join("; ") || texts.sheet.nothing))
}

function missesHtml(misses, texts) {
  if (!misses) return ""
  return misses.map(({ night, shooter, target, miss }) => `<div>${escapeHtml(fill(texts.strip.night, { number: night }))}: ${shooter} → ${escapeHtml(miss ? texts.night[miss] : target)}</div>`).join("")
}

function checksSection(checks, texts) {
  if (!checks) return section(texts.sheet.checks, escapeHtml(texts.log.hidden))
  const cell = (check) => (check ? `${check.seat} ${texts.sheet[`check_${check.result}`]}` : "—")
  const rows = checks.map(({ night, don, sheriff }) => [night, cell(don), cell(sheriff)])
  return section(texts.sheet.checks, rows.length ? table([[texts.sheet.night, texts.sheet.don, texts.sheet.sheriff], ...rows]) : escapeHtml(texts.sheet.nothing))
}

function roundHtml(round, texts) {
  const rows = round.votes.map(({ candidates, voters }) => [seatsList(candidates), voters.length, seatsList(voters)])
  const title = `${round.day === 0 ? texts.strip.zero : fill(texts.strip.day, { number: round.day })}, ${texts.sheet[`round_${round.type}`]}`
  const outcome = round.outcome ? `<div>${escapeHtml(texts.sheet[`outcome_${round.outcome}`])}${round.reason ? `: ${escapeHtml(texts.sheet[`reason_${round.reason}`])}` : ""}</div>` : ""
  return section(title, table([[texts.sheet.candidate, texts.sheet.count, texts.sheet.voters], ...rows]) + outcome)
}

function renderSheet(state, ui, texts) {
  const sheet = buildSheet(state, { rolesShown: rolesShown(state, ui) })
  const shots = sheet.shots.length ? table([sheet.shots.map(({ target }) => target)]) : escapeHtml(texts.sheet.nothing)
  const hint = sheet.sheriffBonusHint ? `<div class="lp-good">${escapeHtml(texts.sheet.sheriff_bonus)}</div>` : ""
  const wills = sheet.wills.map(({ seat, text }) => `<div><b>${seat}</b> ${escapeHtml(willPreview(text, texts))}</div>`).join("")
  const moves = sheet.bestMoves.map(({ seat, seats, noPoints }) => `<div><b>${seat}</b> ${seatsList(seats)}${noPoints ? ` (${escapeHtml(texts.sheet.no_points)})` : ""}</div>`).join("")
  return `<div class="lp-sheet">
    ${dealSection(sheet.deal, texts)}${hint}
    ${section(texts.sheet.shots, shots + missesHtml(sheet.misses, texts))}
    ${checksSection(sheet.checks, texts)}
    ${sheet.rounds.map((round) => roundHtml(round, texts)).join("")}
    ${section(texts.sheet.wills, wills + moves || escapeHtml(texts.sheet.nothing))}
  </div>`
}

function tabsHtml(ui, texts) {
  const tab = (name, label) => `<button type="button" class="lp-tab${ui.tab === name ? " lp-tab--on" : ""}" data-tab="${name}">${escapeHtml(label)}</button>`
  return `<div class="lp-tabs">${tab("log", texts.log.title)}${tab("sheet", texts.sheet.title)}</div>`
}

function stageLabel(event, texts) {
  if (event.phase === "deal") return texts.strip.deal
  if (event.phase === "night") return fill(texts.strip.night, { number: event.day_number + 1 })
  return event.day_number === 0 ? texts.strip.zero : fill(texts.strip.day, { number: event.day_number })
}

function filteredBlock(state, ui, texts, title, events) {
  let current = null
  const rows = events.map((event) => {
    const label = stageLabel(event, texts)
    const header = label === current ? "" : `<h4 class="lp-stage">${escapeHtml(label)}</h4>`
    current = label
    return header + logEntry(state, ui, texts, event)
  }).join("")
  return `<div class="lp-group"><h3>${escapeHtml(title)}</h3>${rows || escapeHtml(texts.sheet.nothing)}</div>`
}

function outcomeOf(state, seat) {
  const result = state.log.findLast((event) => event.kind === "game_finished")?.metadata.result
  if (result === "draw") return "draw"
  const black = ["don", "mafia"].includes(state.players[seat].role)
  return (result === "mafia_victory") === black ? "win" : "lose"
}

function filteredLog(state, ui, texts) {
  const seat = ui.filter
  const player = state.players[seat]
  if (!player) return `<div class="lp-log">${escapeHtml(texts.filter.empty_seat)}</div>`
  const { actions, received } = playerEvents(state, seat)
  return `<div class="lp-log">
    <div class="lp-filter"><b>${seat} ${nameOf(state, seat)}</b>
      <span class="lp-role lp-role--${player.role}" data-role="${player.role}">${escapeHtml(texts.roles[player.role])}</span>
      <span>${escapeHtml(texts.filter[`outcome_${outcomeOf(state, seat)}`])}</span></div>
    ${filteredBlock(state, ui, texts, texts.filter.actions, actions)}
    ${filteredBlock(state, ui, texts, texts.filter.received, received)}
  </div>`
}

function logPanel(state, ui, texts, log) {
  if (ui.filter && state.stage === "finished") return filteredLog(state, ui, texts)
  return `<div class="lp-log">${log}</div>`
}

export function renderScreen(state, ui, texts, hint = "", connection = "saved") {
  const log = state.log.map((event) => logEntry(state, ui, texts, event)).join("")
  const status = rolesShown(state, ui) ? texts.common.roles_shown : texts.common.roles_hidden
  const problem = connection === "offline" || connection === "rejected"
  return `<div class="lp-top"><span class="lp-status${problem ? " lp-status--bad" : ""}" role="status">${escapeHtml(texts.connection[connection])}</span><span class="lp-meta">${escapeHtml(status)}</span></div>
    <div class="lp-steps">${stripHtml(state, texts)}</div>
    <div class="lp-main">
      <div class="lp-col" data-scroll="seats">${SEATS.map((seat) => seatHtml(state, ui, texts, seat)).join("")}</div>
      <div class="lp-col lp-work" id="lp-work">${STAGE_VIEWS[state.stage](state, ui, texts)}</div>
      <div class="lp-col" data-scroll="${ui.tab}">${tabsHtml(ui, texts)}${ui.tab === "sheet" ? renderSheet(state, ui, texts) : logPanel(state, ui, texts, log)}</div>
    </div>
    ${hint ? `<div class="lp-flash" role="status">${escapeHtml(hint)}</div>` : ""}`
}
