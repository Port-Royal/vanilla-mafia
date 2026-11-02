// What one player did and what was done to them, for the judge's review after the game.
import { parseWill } from "live_protocol/will_parser"

// Stage moves and turns say nothing about a player's play.
const NOISE = ["speaker", "leaving_closed", "roles", "deal", "night_closed", "vote_skipped", "round_cancelled", "round_closed", "game_finished"]
// These name the player they happen to, which makes them the player's own record.
const OWN = ["foul", "tech", "sanction_cancelled", "player_left", "player_restored"]
const BLACK_ROLES = ["don", "mafia"]

function willNames(event, seat) {
  const { red, black, sheriff } = parseWill(event.text)
  return [...red, ...black, ...sheriff].includes(seat)
}

export function playerEvents(state, seat) {
  const black = BLACK_ROLES.includes(state.players[seat].role)
  const actions = []
  const received = []
  let out = false

  state.log.forEach((event) => {
    if (NOISE.includes(event.kind)) return
    const named = event.target_seats.includes(seat)
    const voted = event.kind === "vote" && event.metadata.voters.includes(seat)
    const shot = event.kind === "shot" && black && !out
    const own = OWN.includes(event.kind) && named

    if (event.actor_seat === seat || voted || shot || own) actions.push(event)
    if (!OWN.includes(event.kind) && (named || (event.kind === "will" && willNames(event, seat)))) received.push(event)

    if (named && event.kind === "player_left") out = true
    if (named && event.kind === "player_restored") out = false
  })
  return { actions, received }
}
