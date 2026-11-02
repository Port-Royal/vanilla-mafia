// The rules of the game. An action of the judge becomes events, and the state is always the replay
// of the journal. No DOM and no network here, so the module runs in the browser and in tests alike.

const TABLE_SIZE = 10
const ROLE_SET = { don: 1, sheriff: 1, mafia: 2 }
const SPEECH_NOTES = { suspect: "suspect", red: "red", team: "team", check_request: "check_request" }

const alive = (state, seat) => Boolean(state.players[seat]) && !state.players[seat].out
const tableSeat = (from, offset) => ((from + offset - 1) % TABLE_SIZE) + 1

function nextAlive(state, from) {
  for (let offset = 1; offset <= TABLE_SIZE; offset += 1) {
    const seat = tableSeat(from, offset)
    if (alive(state, seat)) return seat
  }
  return null
}

// The circle ends on reaching its first seat, whether or not that player is still in the game.
function nextInCircle(state, from) {
  for (let offset = 1; offset <= TABLE_SIZE; offset += 1) {
    const seat = tableSeat(from, offset)
    if (seat === state.firstSpeaker) return null
    if (alive(state, seat)) return seat
  }
  return null
}

function moveSpeaker(state, seat) {
  state.speaker = seat
  if (seat === null) state.stage = "vote"
}

const APPLY = {
  roles(state, event) {
    Object.entries(event.metadata.roles).forEach(([seat, role]) => { state.players[seat].role = role })
    state.stage = "deal"
  },
  deal(state, event) {
    state.deal = { mode: event.metadata.mode, shot: event.metadata.shot, sheriff: event.target_seats[0] ?? null, text: event.text }
    state.firstSpeaker = nextAlive(state, 0)
    state.speaker = state.firstSpeaker
    state.stage = "speech"
  },
  speaker(state, event) {
    moveSpeaker(state, event.actor_seat)
  },
  nominate(state, event) {
    state.candidates.push(event.target_seats[0])
    state.nominatedBy[event.actor_seat] = event.target_seats[0]
  },
  nomination_cancelled(state, event) {
    const [seat] = event.target_seats
    state.candidates = state.candidates.filter((candidate) => candidate !== seat)
    Object.keys(state.nominatedBy).forEach((by) => {
      if (state.nominatedBy[by] === seat) delete state.nominatedBy[by]
    })
  },
  player_left(state, event) {
    event.target_seats.forEach((seat) => {
      state.players[seat].out = true
      state.players[seat].outReason = event.metadata.reason
      if (state.speaker === seat) moveSpeaker(state, nextInCircle(state, seat))
    })
  },
  night_closed(state) {
    state.day += 1
    state.firstSpeaker = nextAlive(state, state.firstSpeaker)
    state.speaker = state.firstSpeaker
    state.candidates = []
    state.nominatedBy = {}
    state.stage = "speech"
  }
}

export function replay(players, events) {
  const state = {
    stage: "roles",
    day: 0,
    speaker: null,
    firstSpeaker: null,
    candidates: [],
    nominatedBy: {},
    deal: { mode: null, shot: null, sheriff: null, text: null },
    players: {},
    log: []
  }
  players.forEach(({ seat, name, role_code: role }) => {
    state.players[seat] = { name, role, fouls: 0, tech: 0, out: false, outReason: null }
  })
  events.forEach((event) => {
    if (Object.hasOwn(APPLY, event.kind)) APPLY[event.kind](state, event)
    state.log.push(event)
  })
  return state
}

const phaseOf = (state) => (["roles", "deal"].includes(state.stage) ? "deal" : "day")
const refuse = (error) => ({ events: [], error })

function write(state, kind, fields = {}) {
  return {
    events: [{
      kind,
      phase: phaseOf(state),
      day_number: state.day,
      actor_seat: fields.actor_seat ?? null,
      target_seats: fields.target_seats ?? [],
      text: fields.text ?? null,
      metadata: fields.metadata ?? {}
    }],
    error: null
  }
}

function completeFormRoles(state) {
  const roles = Object.values(state.players).map((player) => player.role)
  const counts = (code) => roles.filter((role) => role === code).length
  return Object.entries(ROLE_SET).every(([code, count]) => counts(code) === count) &&
    counts("peace") === roles.length - 4
}

function rolesFromSeats(state, seats) {
  if (new Set(seats).size !== 4 || !seats.every((seat) => state.players[seat])) return null
  const [don, sheriff, ...mafia] = seats
  const roles = {}
  Object.keys(state.players).forEach((seat) => { roles[seat] = "peace" })
  roles[don] = "don"
  roles[sheriff] = "sheriff"
  mafia.forEach((seat) => { roles[seat] = "mafia" })
  return roles
}

function formRoles(state) {
  if (!completeFormRoles(state)) return null
  return Object.fromEntries(Object.entries(state.players).map(([seat, player]) => [seat, player.role]))
}

function oneSeat(action) {
  return action.seats?.length === 1 ? action.seats[0] : null
}

function nominate(state, action) {
  const seat = oneSeat(action)
  if (seat === null) return refuse("one_seat_required")
  if (!alive(state, seat)) return refuse("not_alive")
  if (state.candidates.includes(seat)) return refuse("already_candidate")
  if (Object.hasOwn(state.nominatedBy, state.speaker)) return refuse("already_nominated_today")
  return write(state, "nominate", { actor_seat: state.speaker, target_seats: [seat] })
}

function cancelNomination(state, action) {
  const seat = oneSeat(action)
  if (seat === null) return refuse("one_seat_required")
  if (!state.candidates.includes(seat)) return refuse("not_candidate")
  return write(state, "nomination_cancelled", { actor_seat: state.speaker, target_seats: [seat] })
}

function speechNote(state, action) {
  if (!action.seats?.length) return refuse("seats_required")
  const seats = [...new Set(action.seats)]
  if (!seats.every((seat) => state.players[seat])) return refuse("seat_empty")
  return write(state, SPEECH_NOTES[action.type], { actor_seat: state.speaker, target_seats: seats })
}

function setSpeaker(state, action) {
  const seat = oneSeat(action)
  if (seat === null) return refuse("one_seat_required")
  if (!alive(state, seat)) return refuse("not_alive")
  return write(state, "speaker", { actor_seat: seat })
}

const SPEECH_ACTIONS = {
  nominate,
  cancel_nomination: cancelNomination,
  set_speaker: setSpeaker,
  next_speaker: (state) => write(state, "speaker", { actor_seat: nextInCircle(state, state.speaker) }),
  start_vote: (state) => write(state, "speaker"),
  note(state, action) {
    if (!action.text?.trim()) return refuse("text_required")
    return write(state, "note", { actor_seat: state.speaker, text: action.text })
  }
}

function assignRoles(state, action) {
  if (state.stage !== "roles") return refuse("wrong_stage")
  const roles = action.seats ? rolesFromSeats(state, action.seats) : formRoles(state)
  if (!roles) return refuse("roles_incomplete")
  return write(state, "roles", { metadata: { roles } })
}

function finishDeal(state, action) {
  if (state.stage !== "deal") return refuse("wrong_stage")
  const shot = action.shot ?? null
  const seats = action.seats ?? []
  if (seats.length > 1) return refuse("one_seat_required")
  if (![...seats, ...(shot === null ? [] : [shot])].every((seat) => state.players[seat])) return refuse("seat_empty")
  return write(state, "deal", { target_seats: seats, text: action.text, metadata: { mode: action.mode ?? null, shot } })
}

function removePlayer(state, action) {
  const seat = oneSeat(action)
  if (seat === null) return refuse("one_seat_required")
  if (!alive(state, seat)) return refuse("not_alive")
  return write(state, "player_left", { target_seats: [seat], metadata: { reason: "removed" } })
}

export function decide(state, action) {
  if (action.type === "assign_roles") return assignRoles(state, action)
  if (action.type === "finish_deal") return finishDeal(state, action)
  if (action.type === "remove_player") return removePlayer(state, action)

  const speechAction = Object.hasOwn(SPEECH_NOTES, action.type) ? speechNote : SPEECH_ACTIONS[action.type]
  if (!speechAction) return refuse("unknown_action")
  if (state.stage !== "speech") return refuse("wrong_stage")
  return speechAction(state, action)
}
