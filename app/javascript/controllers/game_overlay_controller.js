import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { gameId: Number }
  static targets = ["playerName", "roleCode", "bestMove"]

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
      best_move: "bestMove"
    }
    return mapping[field]
  }

  updateRoleDisplay(target, roleCode) {
    if (roleCode) {
      target.innerHTML = `<img src="/assets/roles/${roleCode}.png" alt="${roleCode}" class="inline-block h-5 w-5" title="${roleCode}">`
    } else {
      target.textContent = ""
    }
  }
}
