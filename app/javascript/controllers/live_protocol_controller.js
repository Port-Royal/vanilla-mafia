import { Controller } from "@hotwired/stimulus"
import { decide, replay } from "live_protocol/machine"
import { canDelete, emptyUi, handleKey, restorePlayers, stamp, undoGroup } from "live_protocol/console"
import { renderScreen, willPreview } from "live_protocol/screen"
import { applyQueued, PermanentError, SendQueue } from "live_protocol/send_queue"

const FOCUS_TARGETS = { deal_text: "lp-deal-text", pending_text: "lp-pending-text" }

export default class extends Controller {
  static values = { players: Array, events: Array, texts: Object, gameId: Number, eventsUrl: String, afterFinishUrl: String }

  connect() {
    this.connection = "saved"
    this.queue = new SendQueue({
      post: (events) => this.request(this.eventsUrlValue, "POST", { events }),
      remove: (actionId) => this.request(`${this.eventsUrlValue}/${encodeURIComponent(actionId)}`, "DELETE"),
      storage: window.localStorage,
      storageKey: `live_protocol_queue_${this.gameIdValue}`,
      onStatus: (status) => this.connectionChanged(status)
    })
    const { events, removed } = applyQueued(this.eventsValue, this.queue.items)
    this.players = restorePlayers(this.playersValue, removed)
    this.events = events
    this.ui = emptyUi()
    this.willBlurred = false
    this.scroll = {}
    this.onKeydown = this.keydown.bind(this)
    this.onKeyup = this.keyup.bind(this)
    this.onBlur = this.hideRoles.bind(this)
    this.onClick = this.click.bind(this)
    this.onInput = this.input.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("keyup", this.onKeyup)
    window.addEventListener("blur", this.onBlur)
    this.element.addEventListener("click", this.onClick)
    this.element.addEventListener("input", this.onInput)
    this.render()
    this.queue.flush()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("keyup", this.onKeyup)
    window.removeEventListener("blur", this.onBlur)
    this.element.removeEventListener("click", this.onClick)
    this.element.removeEventListener("input", this.onInput)
  }

  get state() {
    return replay(this.players, this.events)
  }

  send(events) {
    this.queue.enqueue(events)
  }

  remove(actionId) {
    this.queue.enqueueDelete(actionId)
  }

  // A network failure or a server error is worth repeating. Anything else the server refused
  // will be refused again, so the queue stops and the screen says so.
  async request(url, method, body) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token },
      body: body && JSON.stringify(body)
    })
    if (response.ok) return
    if (response.status < 500) throw new PermanentError(response.status)
    throw new Error(`Server error: ${response.status}`)
  }

  connectionChanged(status) {
    this.connection = status
    if (status === "saved" && this.finishing) {
      window.location.assign(this.afterFinishUrlValue)
      return
    }
    this.renderStatus()
  }

  // Rebuilding the screen would take the cursor out of the field the judge is typing in.
  renderStatus() {
    const badge = this.element.querySelector(".lp-status")
    if (!badge) return
    badge.textContent = this.textsValue.connection[this.connection]
    badge.classList.toggle("lp-status--bad", ["offline", "rejected"].includes(this.connection))
  }

  keydown(event) {
    if (event.target.matches?.("input")) {
      this.keydownInField(event)
      return
    }
    const key = { code: event.code, shift: event.shiftKey, ctrl: event.ctrlKey || event.metaKey, repeat: event.repeat }
    if (event.altKey) return
    const before = this.ui
    const result = handleKey(this.ui, this.state, key)
    if (result.ui === before && !result.action && !result.undo && !result.hint && !result.focus) return
    event.preventDefault()
    this.apply(result)
  }

  keydownInField(event) {
    const { id } = event.target
    if (event.code === "Escape") {
      event.preventDefault()
      if (id === "lp-pending-text") this.apply({ ui: { ...this.ui, pending: null } })
      else if (id === "lp-will") { this.willBlurred = true; event.target.blur() } else event.target.blur()
      return
    }
    if (event.code !== "Enter") return
    event.preventDefault()
    if (id === "lp-pending-text") {
      const text = event.target.value
      this.apply({ ui: { ...this.ui, pending: null }, ...(text.trim() ? { action: { type: this.ui.pending.type, text } } : {}) })
    } else {
      event.target.blur()
      this.apply(handleKey(this.ui, this.state, { code: "Enter", shift: false, ctrl: false, repeat: false }))
    }
  }

  keyup(event) {
    if (event.code === "KeyH") this.hideRoles()
  }

  hideRoles() {
    if (!this.ui.reveal) return
    this.ui = { ...this.ui, reveal: false }
    this.render()
  }

  input(event) {
    if (event.target.id === "lp-will") {
      this.ui = { ...this.ui, will: event.target.value }
      this.element.querySelector("#lp-will-preview").textContent = willPreview(event.target.value, this.textsValue)
    } else if (event.target.id === "lp-deal-text") {
      this.ui = { ...this.ui, deal: { ...this.ui.deal, text: event.target.value } }
    }
  }

  click(event) {
    const tab = event.target.closest("[data-tab]")
    if (tab) {
      this.ui = { ...this.ui, tab: tab.dataset.tab }
      this.render()
      return
    }
    const cancel = event.target.closest("[data-cancel]")
    if (cancel) {
      event.preventDefault()
      this.apply({ ui: this.ui, action: { type: cancel.dataset.cancel, seats: [Number(cancel.dataset.cancelSeat)] } })
      return
    }
    const remove = event.target.closest("[data-delete]")
    if (remove) {
      this.deleteAction(remove.dataset.delete)
      return
    }
    const button = event.target.closest("[data-code]")
    if (button) {
      this.apply(handleKey(this.ui, this.state, { code: button.dataset.code, shift: button.dataset.shift === "true", ctrl: false, repeat: false }))
      return
    }
    const seat = event.target.closest("[data-seat]")
    if (seat) this.clickSeat(Number(seat.dataset.seat))
  }

  clickSeat(seat) {
    const { state } = this
    if (state.stage === "speech" && !this.ui.pending) {
      this.apply({ ui: this.ui, action: { type: "set_speaker", seats: [seat] } })
      return
    }
    this.apply(handleKey(this.ui, state, { code: `Digit${seat % 10}`, shift: false, ctrl: false, repeat: false }))
  }

  apply(result) {
    this.ui = result.ui
    this.hint = result.hint ? this.textsValue.errors[result.hint] : ""
    if (result.undo) this.undo()
    if (result.action) this.perform(result.action)
    this.render(result.focus)
  }

  perform(action) {
    const { events, error } = decide(this.state, action)
    if (error) {
      this.hint = this.textsValue.errors[error]
      return
    }
    const stamped = stamp(events, () => crypto.randomUUID())
    this.events = [...this.events, ...stamped]
    this.willBlurred = false
    this.finishing = stamped.some((event) => event.kind === "game_finished")
    this.send(stamped)
  }

  undo() {
    const group = undoGroup(this.events)
    if (!group) return
    this.events = group.kept
    this.players = restorePlayers(this.players, group.removed)
    this.remove(group.actionId)
    this.willBlurred = false
  }

  deleteAction(actionId) {
    if (!canDelete(this.events, actionId)) {
      this.hint = this.textsValue.errors.cannot_delete
      this.render()
      return
    }
    this.players = restorePlayers(this.players, this.events.filter((event) => event.action_id === actionId))
    this.events = this.events.filter((event) => event.action_id !== actionId)
    this.remove(actionId)
    this.hint = ""
    this.render()
  }

  render(focus) {
    const { state } = this
    this.saveScroll()
    this.element.innerHTML = renderScreen(state, this.ui, this.textsValue, this.hint, this.connection)
    this.restoreScroll()
    const field = this.fieldToFocus(state, focus)
    if (field) {
      field.focus()
      field.setSelectionRange(field.value.length, field.value.length)
    }
  }

  // Every render replaces the panels, so their scroll offsets are kept by name: the seat list,
  // and each tab of the side panel on its own.
  saveScroll() {
    this.element.querySelectorAll("[data-scroll]").forEach((panel) => { this.scroll[panel.dataset.scroll] = panel.scrollTop })
  }

  restoreScroll() {
    this.element.querySelectorAll("[data-scroll]").forEach((panel) => { panel.scrollTop = this.scroll[panel.dataset.scroll] ?? 0 })
  }

  fieldToFocus(state, focus) {
    if (focus) return this.element.querySelector(`#${FOCUS_TARGETS[focus]}`)
    if (this.ui.pending || this.willBlurred || this.ui.reveal || state.stage !== "leaving") return null
    return this.element.querySelector("#lp-will")
  }
}
