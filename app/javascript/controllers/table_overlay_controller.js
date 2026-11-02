import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// The overlay of one table: reloads onto the table's current game whenever the server announces
// a different one, and after a lost connection, since an announcement may have been missed.
export default class extends Controller {
  static values = { table: Number, gameId: String }

  connect() {
    this.connectedOnce = false
    this.subscription = createConsumer().subscriptions.create(
      { channel: "TableOverlayChannel", table: this.tableValue },
      {
        connected: () => this.connected(),
        received: (data) => this.received(data)
      }
    )
  }

  disconnect() {
    this.subscription.unsubscribe()
  }

  connected() {
    if (this.connectedOnce) this.reload()
    this.connectedOnce = true
  }

  received(data) {
    const current = data.game_id === null ? "" : String(data.game_id)
    if (current !== this.gameIdValue) this.reload()
  }

  reload() {
    window.location.reload()
  }
}
