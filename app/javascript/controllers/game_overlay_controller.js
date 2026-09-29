import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = {
    gameId: Number,
    roleBadges: Object,
    defaultPhoto: String,
    tableTemplate: String,
    judgeTemplate: String
  }
  static targets = ["tile", "photo", "playerName", "roleBadge", "status", "statusIconTemplate", "table", "judge"]

  connect() {
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
    }
  }

  updateHeader(data) {
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

  updateParticipation(data) {
    const seat = parseInt(data.seat)
    const value = data.value

    if (data.field === "player_name") {
      this.updatePlayerName(seat, value)
    } else if (data.field === "role_code") {
      this.updateRoleBadge(seat, value)
    } else if (data.field === "status") {
      this.updateStatus(seat, value)
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
    this.updateStatus(seat, null)

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

  seatTarget(targets, seat) {
    return targets.find((t) => parseInt(t.dataset.seat) === seat)
  }
}
