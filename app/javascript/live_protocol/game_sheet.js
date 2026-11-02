// The paper sheet of the game, built from the journal. With roles hidden, whatever could give a
// role away stays out of the result altogether.
import { parseWill } from "live_protocol/will_parser"

const nightOf = (event) => event.day_number + 1
const nightEvents = (state, kinds) => state.log.filter((event) => kinds.includes(event.kind))

function shots(state) {
  const byNight = new Map()
  nightEvents(state, ["shot", "miss_shot"]).forEach((event) => {
    byNight.set(nightOf(event), event.kind === "shot" ? event.target_seats[0] : "X")
  })
  return [...byNight].map(([night, target]) => ({ night, target }))
}

function misses(state) {
  return nightEvents(state, ["miss_shot"]).map((event) => ({
    night: nightOf(event),
    shooter: event.actor_seat,
    target: event.target_seats[0] ?? null,
    miss: event.metadata.miss
  }))
}

const checkOf = (event) => (event.target_seats.length ? { seat: event.target_seats[0], result: event.metadata.result } : null)

function checks(state) {
  const byNight = new Map()
  nightEvents(state, ["don_check", "sheriff_check"]).forEach((event) => {
    const night = nightOf(event)
    const row = byNight.get(night) ?? { night, don: null, sheriff: null }
    row[event.kind === "don_check" ? "don" : "sheriff"] = checkOf(event)
    byNight.set(night, row)
  })
  return [...byNight.values()]
}

function rounds(state) {
  const all = []
  let current = null
  let nextType = "main"
  const close = (fields) => {
    Object.assign(current, fields)
    current = null
  }

  state.log.forEach((event) => {
    if (event.kind === "vote") {
      if (!current) {
        current = { day: event.day_number, type: nextType, votes: [], outcome: null, leaders: [], reason: null }
        all.push(current)
      }
      current.votes.push({ candidates: event.target_seats, voters: event.metadata.voters, auto: event.metadata.auto })
    } else if (event.kind === "round_closed") {
      const { outcome, leaders, reason = null } = event.metadata
      close({ outcome, leaders, reason })
      nextType = ["repeat", "lift"].includes(outcome) ? outcome : "main"
    } else if (event.kind === "round_cancelled" && current) {
      close({ outcome: "cancelled" })
      nextType = "main"
    }
  })
  return all
}

function sheriffBonus(state) {
  const firstShot = nightEvents(state, ["shot"]).find((event) => nightOf(event) === 1)
  return state.deal.mode === "dynamic" && Boolean(firstShot) && state.players[firstShot.target_seats[0]].role === "sheriff"
}

export function buildSheet(state, { rolesShown }) {
  return {
    deal: rolesShown ? state.deal : null,
    shots: shots(state),
    misses: rolesShown ? misses(state) : null,
    checks: rolesShown ? checks(state) : null,
    rounds: rounds(state),
    wills: nightEvents(state, ["will"]).map((event) => ({ seat: event.actor_seat, text: event.text, ...parseWill(event.text) })),
    bestMoves: nightEvents(state, ["best_move"]).filter((event) => event.target_seats.length).map((event) => ({
      seat: event.actor_seat,
      seats: event.target_seats,
      noPoints: Boolean(event.metadata.no_points)
    })),
    sheriffBonusHint: rolesShown && sheriffBonus(state)
  }
}
