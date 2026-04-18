import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { gameId: Number, roleIconTemplate: String }
  static targets = ["playerName", "roleCode", "status"]

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
    }
  }

  updateParticipation(data) {
    const seat = data.seat
    const field = data.field
    const value = data.value

    const target = this.findTarget(field, seat)
    if (target) {
      if (field === "role_code") {
        this.updateRoleDisplay(target, value)
      } else {
        target.textContent = value || ""
      }
    }

    if (field === "player_name" && (!value || value.trim() === "")) {
      this.clearSeat(seat)
    }
  }

  clearSeat(seat) {
    const roleTarget = this.findTarget("role_code", seat)
    if (roleTarget) {
      this.updateRoleDisplay(roleTarget, null)
    }

    const statusTarget = this.findTarget("status", seat)
    if (statusTarget) {
      statusTarget.textContent = ""
    }
  }

  findTarget(field, seat) {
    const targetName = this.fieldToTarget(field)
    if (!targetName) return null

    const targets = this[`${targetName}Targets`]
    return targets.find((t) => parseInt(t.dataset.seat) === seat)
  }

  fieldToTarget(field) {
    const mapping = {
      player_name: "playerName",
      role_code: "roleCode",
      status: "status"
    }
    return mapping[field]
  }

  updateRoleDisplay(target, roleCode) {
    target.textContent = ""

    if (roleCode && this.hasRoleIconTemplateValue) {
      const src = this.roleIconTemplateValue.replace("%ROLE_CODE%", roleCode)
      const img = document.createElement("img")
      img.src = src
      img.alt = roleCode
      img.title = roleCode
      img.className = "inline-block h-4 w-4"
      target.appendChild(img)
    }
  }
}
