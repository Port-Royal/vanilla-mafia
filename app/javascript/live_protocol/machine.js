// The rules of the game. An action of the judge becomes events, and the state is always the replay
// of the journal. No DOM and no network here, so the module runs in the browser and in tests alike.

const TABLE_SIZE = 10
const ROLE_SET = { don: 1, sheriff: 1, mafia: 2 }
const SPEECH_NOTES = { suspect: "suspect", red: "red", team: "team", check_request: "check_request" }
const SANCTION_LIMITS = { foul: 4, tech: 2 }
const SANCTION_COUNTERS = { foul: "fouls", tech: "tech" }
const FIRST_NIGHT_STEP = "night_shot"
const STAGES_WITHOUT_SANCTIONS = ["roles", "deal"]

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

const aliveSeats = (state) => Object.keys(state.players).map(Number).filter((seat) => alive(state, seat))
const newRound = (type, candidates) => ({ type, candidates, index: 0, votes: {} })

function moveSpeaker(state, seat) {
  state.speaker = seat
  if (seat === null) {
    state.stage = "vote"
    state.round = newRound("main", state.candidates)
  }
}

function toNight(state) {
  state.stage = FIRST_NIGHT_STEP
  state.round = null
}

// True when the votes still to come cannot catch the leader, so the outcome is already known.
export function voteDecided(round, seats) {
  const counts = Object.values(round.votes).map((voters) => voters.length).sort((a, b) => b - a)
  const voted = new Set(Object.values(round.votes).flat())
  const remaining = seats.filter((seat) => !voted.has(seat)).length
  const [leader = 0, second = 0] = counts
  return leader > second && leader > remaining
}

// Days only move forward, so a repeated removal lands on the vote already cancelled.
function applyRemoval(state, seat) {
  if (state.stage === "speech") {
    state.candidates = state.candidates.filter((candidate) => candidate !== seat)
    state.noVoteDay = state.day
  } else if (state.stage !== "vote" || voteDecided(state.round, aliveSeats(state))) {
    state.noVoteDay = state.day + 1
  }
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
      state.players[seat].removedBy = event.metadata.sanction ?? null
      if (event.metadata.reason === "removed") applyRemoval(state, seat)
      if (state.speaker === seat) moveSpeaker(state, nextInCircle(state, seat))
    })
  },
  night_closed(state) {
    state.day += 1
    state.firstSpeaker = nextAlive(state, state.firstSpeaker)
    state.speaker = state.firstSpeaker
    state.candidates = []
    state.nominatedBy = {}
    state.leaving = []
    state.stage = "speech"
  },
  vote(state, event) {
    const key = event.metadata.lift ? "lift" : event.target_seats[0]
    state.round.votes[key] = event.metadata.voters
    state.round.index += 1
  },
  round_closed(state, event) {
    const { outcome, leaders } = event.metadata
    if (outcome === "repeat" || outcome === "lift") {
      state.round = newRound(outcome, leaders)
    } else if (outcome === "leave") {
      state.leaving = leaders.filter((seat) => alive(state, seat))
      if (state.leaving.length > 0) {
        state.stage = "leaving"
        state.round = null
      } else {
        toNight(state)
      }
    } else {
      toNight(state)
    }
  },
  vote_skipped: toNight,
  round_cancelled: toNight,
  foul(state, event) {
    state.players[event.target_seats[0]].fouls += 1
  },
  tech(state, event) {
    state.players[event.target_seats[0]].tech += 1
  },
  sanction_cancelled(state, event) {
    state.players[event.target_seats[0]][SANCTION_COUNTERS[event.metadata.sanction]] -= 1
  },
  player_restored(state, event) {
    event.target_seats.forEach((seat) => {
      Object.assign(state.players[seat], { out: false, outReason: null, removedBy: null })
    })
  }
}

function applyEvent(state, event) {
  if (Object.hasOwn(APPLY, event.kind)) APPLY[event.kind](state, event)
  state.log.push(event)
}

export function replay(players, events) {
  const state = {
    stage: "roles",
    day: 0,
    speaker: null,
    firstSpeaker: null,
    candidates: [],
    nominatedBy: {},
    round: null,
    leaving: [],
    noVoteDay: null,
    deal: { mode: null, shot: null, sheriff: null, text: null },
    players: {},
    log: []
  }
  players.forEach(({ seat, name, role_code: role }) => {
    state.players[seat] = { name, role, fouls: 0, tech: 0, out: false, outReason: null, removedBy: null }
  })
  events.forEach((event) => applyEvent(state, event))
  return state
}

function phaseOf(state) {
  if (STAGES_WITHOUT_SANCTIONS.includes(state.stage)) return "deal"
  return state.stage.startsWith("night") ? "night" : "day"
}

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

function sanctionSeat(state, action) {
  return action.seats?.length ? oneSeat(action) : state.speaker
}

function removePlayer(state, action) {
  const seat = sanctionSeat(state, action)
  if (seat === null) return refuse("one_seat_required")
  if (!alive(state, seat)) return refuse("not_alive")
  return write(state, "player_left", { target_seats: [seat], metadata: { reason: "removed" } })
}

function sanction(state, action) {
  const kind = action.type
  const seat = sanctionSeat(state, action)
  if (seat === null) return refuse("one_seat_required")
  if (!alive(state, seat)) return refuse("not_alive")

  const result = write(state, kind, { target_seats: [seat] })
  if (state.players[seat][SANCTION_COUNTERS[kind]] + 1 >= SANCTION_LIMITS[kind]) {
    result.events.push(...write(state, "player_left", { target_seats: [seat], metadata: { reason: "removed", sanction: kind } }).events)
  }
  return result
}

function cancelSanction(state, action) {
  const kind = action.type.replace("cancel_", "")
  const seat = sanctionSeat(state, action)
  if (seat === null) return refuse("one_seat_required")
  if (!state.players[seat]) return refuse("seat_empty")
  if (state.players[seat][SANCTION_COUNTERS[kind]] === 0) return refuse("no_sanction")

  const result = write(state, "sanction_cancelled", { target_seats: [seat], metadata: { sanction: kind } })
  if (state.players[seat].removedBy === kind) result.events.push(...write(state, "player_restored", { target_seats: [seat] }).events)
  return result
}

function liftRefusal(state, leaders) {
  const living = aliveSeats(state).length
  if (state.day === 0 && [5, 10].includes(leaders.length)) return "five_or_ten_zero"
  if (leaders.length === 3 && living === 9) return "three_of_nine"
  return leaders.length * 2 > living ? "over_half" : null
}

function tieOutcome(state, round, leaders) {
  if (round.type === "main" || leaders.length < round.candidates.length) return { outcome: "repeat", leaders }

  const reason = liftRefusal(state, leaders)
  return reason ? { outcome: "none", leaders, reason } : { outcome: "lift", leaders }
}

function roundOutcome(state) {
  const { round } = state
  if (round.type === "lift") {
    const majority = round.votes.lift.length * 2 > aliveSeats(state).length
    return { outcome: majority ? "leave" : "none", leaders: round.candidates }
  }

  const count = (seat) => (round.votes[seat] ?? []).length
  const top = Math.max(...round.candidates.map(count))
  const leaders = round.candidates.filter((seat) => count(seat) === top)
  return leaders.length === 1 ? { outcome: "leave", leaders } : tieOutcome(state, round, leaders)
}

function closingEvents(state) {
  const metadata = roundOutcome(state)
  const events = write(state, "round_closed", { target_seats: metadata.leaders, metadata }).events
  if (metadata.outcome !== "leave") return events

  const departing = metadata.leaders.filter((seat) => alive(state, seat))
  return events.concat(departing.flatMap((seat) => write(state, "player_left", { target_seats: [seat], metadata: { reason: "voted" } }).events))
}

function voteFor(state, action) {
  if (state.stage !== "vote") return refuse("wrong_stage")

  const { round } = state
  const marked = [...new Set(action.seats ?? [])]
  const voted = new Set(Object.values(round.votes).flat())
  if (!marked.every((seat) => alive(state, seat))) return refuse("not_alive")
  if (marked.some((seat) => voted.has(seat))) return refuse("already_voted")

  const lift = round.type === "lift"
  const last = round.index === round.candidates.length - 1
  const auto = lift || !last ? [] : aliveSeats(state).filter((seat) => !voted.has(seat) && !marked.includes(seat))
  const metadata = { voters: [...marked, ...auto], auto, ...(lift ? { lift } : {}) }
  const target_seats = lift ? round.candidates : [round.candidates[round.index]]
  const { events } = write(state, "vote", { target_seats, metadata })

  const after = simulate(state, events)
  const everybodyVoted = aliveSeats(after).every((seat) => Object.values(after.round.votes).flat().includes(seat))
  if (lift || last || everybodyVoted) events.push(...closingEvents(after))
  return { events, error: null }
}

function simulate(state, events) {
  const copy = structuredClone(state)
  events.forEach((event) => applyEvent(copy, event))
  return copy
}

function skipReason(state) {
  if (state.noVoteDay === state.day) return "cancelled"
  if (state.candidates.length === 0) return "no_candidates"
  return state.day === 0 && state.candidates.length === 1 ? "single_candidate_zero" : null
}

// What the rules make happen right after the judge's own action.
function consequences(before, after, events) {
  if (before.stage === "speech" && after.stage === "vote") {
    const reason = skipReason(after)
    return reason ? write(after, "vote_skipped", { metadata: { reason } }).events : []
  }
  const removed = events.some((event) => event.metadata.reason === "removed")
  if (removed && after.stage === "vote" && !voteDecided(after.round, aliveSeats(after))) {
    return write(after, "round_cancelled").events
  }
  return []
}

const SANCTION_ACTIONS = { remove_player: removePlayer, foul: sanction, tech: sanction, cancel_foul: cancelSanction, cancel_tech: cancelSanction }

function route(state, action) {
  if (action.type === "assign_roles") return assignRoles(state, action)
  if (action.type === "finish_deal") return finishDeal(state, action)
  if (action.type === "vote_for") return voteFor(state, action)
  if (Object.hasOwn(SANCTION_ACTIONS, action.type)) {
    if (STAGES_WITHOUT_SANCTIONS.includes(state.stage)) return refuse("wrong_stage")
    return SANCTION_ACTIONS[action.type](state, action)
  }

  const speechAction = Object.hasOwn(SPEECH_NOTES, action.type) ? speechNote : SPEECH_ACTIONS[action.type]
  if (!speechAction) return refuse("unknown_action")
  if (state.stage !== "speech") return refuse("wrong_stage")
  return speechAction(state, action)
}

export function decide(state, action) {
  const result = route(state, action)
  if (result.error) return result

  const follow = consequences(state, simulate(state, result.events), result.events)
  return { events: [...result.events, ...follow], error: null }
}
