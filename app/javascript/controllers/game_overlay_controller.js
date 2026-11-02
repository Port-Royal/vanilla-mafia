import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

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
    checkTemplate: String,
    checkLabels: Object
  }
  static targets = ["tile", "photo", "playerName", "roleBadge", "status", "statusIconTemplate", "table", "judge", "gameNumber", "bestMove", "nominees", "nomineesList", "checks", "checksList"]

  connect() {
    this.seatRoles = { ...this.seatRolesValue }
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
      this.renderNominees(data.seats)
    } else if (data.scope === "checks") {
      this.renderChecks(data.checks)
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
    if (badge) badge.textContent = Object.hasOwn(this.roleBadgesValue, roleCode) ? this.roleBadgesValue[roleCode] : ""
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
    this.renderChecks([])
    this.seatRoles = {}
    this.roleBadgeTargets.forEach((badge) => { badge.textContent = "" })
    this.bestMoveTargets.forEach((strip) => {
      strip.querySelectorAll("[data-named-seat]").forEach((cell) => this.colourBestMoveCell(cell))
    })
  }

  // Cells naming this seat change colour with its player's role.
  updateSeatRole(seat, roleCode) {
    this.seatRoles[seat] = roleCode
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

  renderNominees(seats) {
    const entries = seats.map((seat) => {
      const entry = document.createElement("span")
      entry.className = "overlay-nominee"
      const name = (this.seatTarget(this.playerNameTargets, seat)?.textContent || "").trim()
      entry.textContent = name ? `${seat} ${name}` : String(seat)
      return entry
    })
    this.nomineesListTarget.replaceChildren(...entries)
    this.nomineesTarget.hidden = seats.length === 0
  }

  renderChecks(checks) {
    if (!this.hasChecksTarget) return
    const labels = this.checkLabelsValue
    const entries = checks.map((check) => {
      const values = {
        NIGHT: check.night,
        WHO: labels[check.kind],
        SEAT: check.target_seat,
        RESULT: labels[check.result]
      }
      const entry = document.createElement("span")
      entry.className = "overlay-check overlay-nominee"
      entry.textContent = this.checkTemplateValue.replace(/%(NIGHT|WHO|SEAT|RESULT)%/g, (_marker, name) => values[name])
      return entry
    })
    this.checksListTarget.replaceChildren(...entries)
    this.checksTarget.hidden = checks.length === 0
  }

  seatTarget(targets, seat) {
    return targets.find((t) => parseInt(t.dataset.seat) === seat)
  }
}
