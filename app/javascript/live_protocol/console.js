// Turns keys into actions for the machine. Keeps only what is being typed: anything that matters
// to the game goes through decide and into the journal. Keys are matched by event.code, so the
// keyboard layout makes no difference.

const SANCTIONS = { KeyF: "foul", KeyG: "tech", KeyX: "remove_player" }
const CANCELS = { KeyF: "cancel_foul", KeyG: "cancel_tech" }
const SPEECH_MULTI = { KeyS: "suspect", KeyR: "red", KeyT: "team", KeyC: "check_request" }
const NO_SANCTIONS = ["roles", "deal", "finished"]
const BEST_MOVE_SEATS = 3

export function emptyUi() {
  return {
    pending: null,
    marks: [],
    deal: { mode: null, sheriff: null, text: "" },
    will: "",
    miss: false,
    reveal: false
  }
}

export function digitOf(code) {
  const match = /^(?:Digit|Numpad)(\d)$/.exec(code)
  if (!match) return null
  return Number(match[1]) || 10
}

const toggle = (seats, seat) => (seats.includes(seat) ? seats.filter((other) => other !== seat) : [...seats, seat])
const open = (ui, type, mode, focus) => ({ ui: { ...ui, pending: { type, mode, seats: [] } }, ...(focus ? { focus } : {}) })
const fire = (ui, action) => ({ ui: { ...ui, pending: null, marks: [], miss: false }, action })

function pendingKey(ui, key) {
  const { pending } = ui
  const seat = digitOf(key.code)
  if (seat !== null) {
    if (pending.mode === "one") return fire(ui, { type: pending.type, seats: [seat] })
    const seats = toggle(pending.seats, seat)
    if (pending.mode === "three" && seats.length === BEST_MOVE_SEATS) return fire(ui, { type: pending.type, seats })
    return { ui: { ...ui, pending: { ...pending, seats } } }
  }
  if (key.code !== "Enter") return { ui }
  if (pending.applyToSpeaker) return fire(ui, { type: pending.type, seats: [] })
  if (pending.mode === "multi" && pending.seats.length) return fire(ui, { type: pending.type, seats: pending.seats })
  return { ui: { ...ui, pending: null } }
}

function openSanction(ui, type) {
  const opened = open(ui, type, "one")
  opened.ui.pending.applyToSpeaker = true
  return opened
}

const STAGES = {
  roles(ui, key, seat) {
    if (seat !== null) return { ui: { ...ui, marks: toggle(ui.marks, seat) } }
    if (key.code !== "Enter") return { ui }
    return fire(ui, ui.marks.length ? { type: "assign_roles", seats: ui.marks } : { type: "assign_roles" })
  },
  deal(ui, key, seat) {
    if (seat !== null) return { ui: { ...ui, deal: { ...ui.deal, sheriff: ui.deal.sheriff === seat ? null : seat } } }
    const mode = { KeyS: "static", KeyD: "dynamic" }[key.code]
    if (mode) return { ui: { ...ui, deal: { ...ui.deal, mode: ui.deal.mode === mode ? null : mode } } }
    if (key.code === "KeyW") return { ui, focus: "deal_text" }
    if (key.code !== "Enter") return { ui }
    const { mode: chosen, sheriff, text } = ui.deal
    return fire(ui, { type: "finish_deal", mode: chosen, seats: sheriff ? [sheriff] : [], text: text || null })
  },
  speech(ui, key, seat) {
    if (seat !== null) return { ui, hint: "choose_action" }
    if (key.shift) return key.code === "KeyN" ? open(ui, "cancel_nomination", "one") : { ui }
    if (SPEECH_MULTI[key.code]) return open(ui, SPEECH_MULTI[key.code], "multi")
    if (key.code === "KeyN") return open(ui, "nominate", "one")
    if (key.code === "KeyM") return open(ui, "note", "text", "pending_text")
    if (key.code === "Space") return fire(ui, { type: "next_speaker" })
    if (key.code === "KeyV") return fire(ui, { type: "start_vote" })
    return { ui }
  },
  vote(ui, key, seat) {
    if (seat !== null) return { ui: { ...ui, marks: toggle(ui.marks, seat) } }
    return key.code === "Enter" ? fire(ui, { type: "vote_for", seats: ui.marks }) : { ui }
  },
  night_shot(ui, key, seat) {
    if (ui.miss) return STAGES.night_miss(ui, key, seat)
    if (seat !== null) return fire(ui, { type: "shoot", seats: [seat] })
    return key.code === "KeyM" ? { ui: { ...ui, miss: true } } : { ui }
  },
  night_miss(ui, key, seat) {
    if (seat !== null) return fire(ui, { type: "miss_shot", seats: [seat] })
    if (key.code === "Minus") return fire(ui, { type: "miss_shot", miss: "no_shot" })
    return key.code === "KeyT" ? fire(ui, { type: "miss_shot", miss: "tactical" }) : { ui }
  },
  night_don: (ui, key, seat) => nightCheck(ui, key, seat, "don_check"),
  night_sheriff: (ui, key, seat) => nightCheck(ui, key, seat, "sheriff_check"),
  best_move(ui, key, seat) {
    if (seat !== null) {
      const marks = toggle(ui.marks, seat)
      return marks.length === BEST_MOVE_SEATS ? fire(ui, { type: "best_move", seats: marks }) : { ui: { ...ui, marks } }
    }
    return key.code === "Enter" && ui.marks.length === 0 ? fire(ui, { type: "best_move", seats: [] }) : { ui }
  },
  leaving(ui, key, seat) {
    if (seat !== null) return { ui, hint: "choose_action" }
    if (key.code === "KeyB") return open(ui, "best_move", "three")
    if (key.code === "Enter" && ui.will) return fire({ ...ui, will: "" }, { type: "will", text: ui.will })
    return key.code === "Enter" || key.code === "Space" ? fire(ui, { type: "finish_leaving" }) : { ui }
  }
}

function nightCheck(ui, key, seat, type) {
  if (seat !== null) return fire(ui, { type, seats: [seat] })
  return key.code === "Enter" ? fire(ui, { type, seats: [] }) : { ui }
}

function sanctionKey(ui, state, key) {
  if (NO_SANCTIONS.includes(state.stage)) return null
  if (key.shift && CANCELS[key.code]) return openSanction(ui, CANCELS[key.code])
  if (!key.shift && SANCTIONS[key.code]) return openSanction(ui, SANCTIONS[key.code])
  if (key.shift && key.code === "KeyD") return fire(ui, { type: "finish_game", result: "draw" })
  if (key.code === "KeyQ" && state.pendingResult) return fire(ui, { type: "finish_game" })
  return null
}

export function handleKey(ui, state, key) {
  if (key.repeat) return { ui }
  if (key.ctrl) return key.code === "KeyZ" ? { ui, undo: true } : { ui }
  if (key.code === "KeyH") return { ui: { ...ui, reveal: true } }
  if (key.code === "Escape") return { ui: { ...ui, pending: null, marks: [], miss: false } }
  if (ui.pending) return pendingKey(ui, key)

  const general = sanctionKey(ui, state, key)
  if (general) return general

  const stage = STAGES[state.stage]
  return stage ? stage(ui, key, digitOf(key.code)) : { ui }
}

export function rolesShown(state, ui) {
  if (ui.reveal || state.pendingResult || state.stage === "finished") return true
  return ["roles", "deal"].includes(state.stage) || state.stage.startsWith("night")
}

export function stamp(events, newId) {
  const actionId = newId()
  return events.map((event) => ({ ...event, client_id: newId(), action_id: actionId }))
}

export function undoGroup(events) {
  if (events.length === 0) return null
  const actionId = events.at(-1).action_id
  return {
    actionId,
    removed: events.filter((event) => event.action_id === actionId),
    kept: events.filter((event) => event.action_id !== actionId)
  }
}

const DELETABLE_FROM_MIDDLE = ["suspect", "red", "team", "check_request", "note", "will", "best_move"]

// Mirrors GameProtocolEvent.removable_group? so the judge hears the answer at once.
export function canDelete(events, actionId) {
  if (events.at(-1).action_id === actionId) return true
  return events.filter((event) => event.action_id === actionId).every(({ kind, day_number: day }) =>
    DELETABLE_FROM_MIDDLE.includes(kind) ||
    (kind === "nominate" && !events.some((event) => event.kind === "vote" && event.day_number === day)))
}

// The page's players already hold what a saved roles event wrote, so undoing it has to hand back
// what that event replaced, or the replay would keep showing the removed roles.
export function restorePlayers(players, removed) {
  const previous = Object.assign({}, ...removed.map((event) => event.metadata.previous_roles ?? {}))
  return players.map((player) => (Object.hasOwn(previous, player.seat) ? { ...player, role_code: previous[player.seat] } : player))
}
