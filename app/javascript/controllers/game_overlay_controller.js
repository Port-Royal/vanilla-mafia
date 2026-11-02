import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Mirrors Game::TEAMS.
const TEAMS = { don: "black", mafia: "black", sheriff: "red", peace: "red" }

export default class extends Controller {
  static values = {
    gameId: Number,
    roleBadges: Object,
    defaultPhoto: String,
    seatRoles: Object,
    bestMoveColours: Object,
    tableTemplate: String,
    judgeTemplate: String,
    gameTemplate: String,
    gameOfTotalTemplate: String,
    nominees: Array,
    shots: Array,
    checks: Array
  }
  static targets = ["tile", "photo", "playerName", "roleBadge", "status", "statusIconTemplate", "table", "judge", "gameNumber", "bestMove", "nominees", "nomineesList", "night", "nightNumbers", "shotsRow", "shotsCells", "donRow", "donCells", "sheriffRow", "sheriffCells", "fouls"]

  connect() {
    this.seatRoles = { ...this.seatRolesValue }
    this.nominees = this.nomineesValue
    this.shots = this.shotsValue
    this.checks = this.checksValue
    this.subscription = createConsumer().subscriptions.create(
      { channel: "GameProtocolChannel", game_id: this.gameIdValue },
      { received: (data) => this.handleUpdate(data) }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  handleUpdate(data) {
    if (data.scope === "participation" && data.seat) {
      this.updateParticipation(data)
    } else if (data.scope === "game") {
      this.updateHeader(data)
    } else if (data.scope === "nominees") {
      this.nominees = data.seats
      this.renderNominees()
    } else if (data.scope === "shots") {
      this.shots = data.shots
      this.renderNight()
    } else if (data.scope === "checks") {
      this.checks = data.checks
      this.renderNight()
    } else if (data.scope === "fouls") {
      this.renderFouls(data.fouls)
    }
  }

  updateHeader(data) {
    const displaySettingClasses = {
      hide_roles: "overlay-canvas--hide-roles",
      hide_game_info: "overlay-canvas--hide-game-info",
      hide_table_info: "overlay-canvas--hide-table-info"
    }
    if (displaySettingClasses[data.field]) {
      this.element.classList.toggle(displaySettingClasses[data.field], data.value === "1")
      if (data.field === "hide_roles" && data.value === "1") this.forgetRoles()
      return
    }

    const gameNumberKeys = { game_number: "number", games_total: "total" }
    if (gameNumberKeys[data.field]) {
      this.updateGameNumber(gameNumberKeys[data.field], data.value)
      return
    }

    const slots = {
      table_number: [this.tableTarget, this.tableTemplateValue],
      judge: [this.judgeTarget, this.judgeTemplateValue]
    }
    const slot = slots[data.field]
    if (!slot) return

    const [target, template] = slot
    const value = (data.value || "").trim()
    target.textContent = value === "" ? "" : template.replace("%VALUE%", () => value)
  }

  updateGameNumber(key, value) {
    const target = this.gameNumberTarget
    target.dataset[key] = (value || "").trim()

    const { number, total } = target.dataset
    const template = total === "" ? this.gameTemplateValue : this.gameOfTotalTemplateValue
    target.textContent = template.replace("%NUMBER%", () => number).replace("%TOTAL%", () => total)
  }

  updateParticipation(data) {
    const seat = parseInt(data.seat)
    const value = data.value

    if (data.field === "player_name") {
      this.updatePlayerName(seat, value)
    } else if (data.field === "role_code") {
      this.updateRoleBadge(seat, value)
      this.updateSeatRole(seat, value)
    } else if (data.field === "status") {
      this.updateStatus(seat, value)
    } else if (data.field === "best_move_seats") {
      this.renderBestMove(seat, value)
    }
  }

  updatePlayerName(seat, name) {
    const trimmed = (name || "").trim()
    const nameTarget = this.seatTarget(this.playerNameTargets, seat)
    if (nameTarget) nameTarget.textContent = trimmed

    if (trimmed === "") this.clearSeat(seat)
  }

  clearSeat(seat) {
    this.updateRoleBadge(seat, null)
    this.updateSeatRole(seat, null)
    this.updateStatus(seat, null)
    this.renderBestMove(seat, [])

    const photo = this.seatTarget(this.photoTargets, seat)
    if (photo) {
      photo.src = this.defaultPhotoValue
      photo.alt = ""
    }
  }

  updateRoleBadge(seat, roleCode) {
    const badge = this.seatTarget(this.roleBadgeTargets, seat)
    if (!badge) return
    const shown = Object.hasOwn(this.roleBadgesValue, roleCode)
    badge.textContent = shown ? this.roleBadgesValue[roleCode] : ""
    if (shown) badge.dataset.role = roleCode
    else delete badge.dataset.role
  }

  updateStatus(seat, status) {
    const iconTemplate = this.statusIconTemplateTargets.find((t) => t.dataset.status === status)

    const tile = this.seatTarget(this.tileTargets, seat)
    if (tile) tile.classList.toggle("overlay-tile--eliminated", Boolean(iconTemplate))

    const slot = this.seatTarget(this.statusTargets, seat)
    if (slot) slot.replaceChildren(...(iconTemplate ? [iconTemplate.content.cloneNode(true)] : []))
  }

  // Roles already delivered must not stay readable in the page once they are hidden.
  forgetRoles() {
    this.checks = []
    this.renderNight()
    this.seatRoles = {}
    this.renderNominees()
    this.roleBadgeTargets.forEach((badge) => {
      badge.textContent = ""
      delete badge.dataset.role
    })
    this.bestMoveTargets.forEach((strip) => {
      strip.querySelectorAll("[data-named-seat]").forEach((cell) => this.colourBestMoveCell(cell))
    })
  }

  // Cells naming this seat change colour with its player's role.
  updateSeatRole(seat, roleCode) {
    this.seatRoles[seat] = roleCode
    this.renderNominees()
    this.bestMoveTargets.forEach((strip) => {
      strip.querySelectorAll(`[data-named-seat="${seat}"]`).forEach((cell) => this.colourBestMoveCell(cell))
    })
  }

  renderBestMove(seat, namedSeats) {
    const strip = this.seatTarget(this.bestMoveTargets, seat)
    if (!strip) return

    const cells = (namedSeats || []).map(String).filter((named) => named !== "").map((named) => {
      const cell = document.createElement("span")
      cell.className = "overlay-best-move-cell"
      cell.dataset.namedSeat = named
      cell.textContent = named
      this.colourBestMoveCell(cell)
      return cell
    })
    strip.replaceChildren(...cells)
  }

  colourBestMoveCell(cell) {
    const roleCode = this.seatRoles[cell.dataset.namedSeat]
    cell.dataset.colour = Object.hasOwn(this.bestMoveColoursValue, roleCode) ? this.bestMoveColoursValue[roleCode] : "neutral"
  }

  renderNominees() {
    if (!this.hasNomineesTarget) return
    this.fillNightRow(this.nomineesListTarget, this.nominees.map((seat) => ({ text: String(seat), colour: this.seatColour(seat) })))
    this.nomineesTarget.hidden = this.nominees.length === 0
  }

  // Mirrors GamesHelper#overlay_seat_colour.
  seatColour(seat) {
    return TEAMS[this.seatRoles[seat]] || "neutral"
  }

  // Mirrors GamesHelper#overlay_foul_pips. A seat missing from the list has no sanctions left.
  renderFouls(fouls) {
    this.foulsTargets.forEach((target) => {
      const count = fouls[target.dataset.seat] || { fouls: 0, tech: 0 }
      const kinds = [...Array(count.fouls).fill("foul"), ...Array(count.tech).fill("tech")]
      target.replaceChildren(...kinds.map((kind) => {
        const pip = document.createElement("span")
        pip.className = `overlay-${kind}`
        return pip
      }))
    })
  }

  // Mirrors GamesHelper#overlay_night_rows: one cell per night so the rows line up.
  renderNight() {
    if (!this.hasNightTarget) return
    const nights = Math.max(0, ...[...this.shots, ...this.checks].map((entry) => entry.night))
    const row = (entries, cellOf) => Array.from({ length: nights }, (_unused, index) => {
      const entry = entries.find((candidate) => candidate.night === index + 1)
      return entry ? cellOf(entry) : { text: "", colour: "none" }
    })
    const checkRow = (kind) => (this.checks.length ? row(this.checks.filter((check) => check.kind === kind), (check) => this.checkCell(check)) : [])

    this.nightNumbersTarget.replaceChildren(...Array.from({ length: nights }, (_unused, index) => {
      const number = document.createElement("span")
      number.className = "overlay-night-number"
      number.textContent = String(index + 1)
      return number
    }))
    this.fillNightRow(this.shotsCellsTarget, row(this.shots, (shot) => this.shotCell(shot)))
    const don = checkRow("don")
    const sheriff = checkRow("sheriff")
    this.fillNightRow(this.donCellsTarget, don)
    this.fillNightRow(this.sheriffCellsTarget, sheriff)
    this.donRowTarget.hidden = don.length === 0
    this.sheriffRowTarget.hidden = sheriff.length === 0
    this.nightTarget.hidden = nights === 0
  }

  shotCell(shot) {
    if (!shot.target_seat) return { text: "×", colour: "empty" }
    return { text: String(shot.target_seat), colour: shot.team || "neutral" }
  }

  checkCell(check) {
    if (!check.target_seat) return { text: "×", colour: "empty" }
    const text = String(check.target_seat)
    if (check.kind === "sheriff") return { text, colour: check.result }
    return check.result === "sheriff" ? { text, colour: "red", mark: "sheriff" } : { text, colour: check.team || "neutral" }
  }

  fillNightRow(target, cells) {
    target.replaceChildren(...cells.map(({ text, colour, mark }) => {
      const cell = document.createElement("span")
      cell.className = "overlay-night-cell"
      cell.textContent = text
      cell.dataset.colour = colour
      if (mark) cell.dataset.mark = mark
      return cell
    }))
  }

  seatTarget(targets, seat) {
    return targets.find((t) => parseInt(t.dataset.seat) === seat)
  }
}
