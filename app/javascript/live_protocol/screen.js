// Builds the console's markup from the state. Secrets that must stay hidden are left out of the
// markup entirely rather than hidden with styles.
import { rolesShown } from "live_protocol/console"
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
    return heading(texts.finish.eyebrow, escapeHtml(texts.finish.done))
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

export function renderScreen(state, ui, texts, hint = "") {
  const log = state.log.map((event) => logEntry(state, ui, texts, event)).join("")
  const status = rolesShown(state, ui) ? texts.common.roles_shown : texts.common.roles_hidden
  return `<div class="lp-top"><span class="lp-meta">${escapeHtml(status)}</span></div>
    <div class="lp-steps">${stripHtml(state, texts)}</div>
    <div class="lp-main">
      <div class="lp-col">${SEATS.map((seat) => seatHtml(state, ui, texts, seat)).join("")}</div>
      <div class="lp-col lp-work" id="lp-work">${STAGE_VIEWS[state.stage](state, ui, texts)}</div>
      <div class="lp-col"><h2 class="lp-tab">${escapeHtml(texts.log.title)}</h2><div class="lp-log">${log}</div></div>
    </div>
    ${hint ? `<div class="lp-flash" role="status">${escapeHtml(hint)}</div>` : ""}`
}
