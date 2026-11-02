import { Controller } from "@hotwired/stimulus"
import { decide, replay } from "live_protocol/machine"
import { canDelete, emptyUi, handleKey, restorePlayers, stamp, undoGroup } from "live_protocol/console"
import { renderScreen, willPreview } from "live_protocol/screen"

const FOCUS_TARGETS = { deal_text: "lp-deal-text", pending_text: "lp-pending-text" }

export default class extends Controller {
  static values = { players: Array, events: Array, texts: Object }

  connect() {
    this.players = this.playersValue
    this.events = this.eventsValue
    this.ui = emptyUi()
    this.willBlurred = false
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

  // Sending to the server arrives with the send queue.
  send() {}
  remove() {}

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
    this.element.innerHTML = renderScreen(state, this.ui, this.textsValue, this.hint)
    const field = this.fieldToFocus(state, focus)
    if (field) {
      field.focus()
      field.setSelectionRange(field.value.length, field.value.length)
    }
  }

  fieldToFocus(state, focus) {
    if (focus) return this.element.querySelector(`#${FOCUS_TARGETS[focus]}`)
    if (this.ui.pending || this.willBlurred || this.ui.reveal || state.stage !== "leaving") return null
    return this.element.querySelector("#lp-will")
  }
}
