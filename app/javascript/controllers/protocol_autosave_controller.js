import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "toggle"]
  static values = {
    url: String,
    savingText: { type: String, default: "..." },
    savedText: { type: String, default: "OK" },
    errorText: { type: String, default: "!" }
  }

  connect() {
    this.active = false
    // Each connection keeps its own state, so a request of an earlier connection that settles late cannot touch it.
    this.state = {
      connected: true,
      // A typed value waits for the typing to pause before it is saved.
      typedValues: new Map(),
      // One request in flight per field; a value changed meanwhile waits and is sent when it finishes.
      requests: new Map(),
      waitingValues: new Map(),
      failedFields: new Set()
    }
    this.pageLeft = () => this.flushOnLeave()
    this.visibilityChanged = () => {
      if (document.visibilityState === "hidden") this.flushOnLeave()
    }
    window.addEventListener("pagehide", this.pageLeft)
    document.addEventListener("visibilitychange", this.visibilityChanged)
  }

  // Requests in flight finish on their own: they are sent with keepalive, and a value waiting for one of them follows
  // it, as the page itself stays loaded when the controller disconnects.
  disconnect() {
    window.removeEventListener("pagehide", this.pageLeft)
    document.removeEventListener("visibilitychange", this.visibilityChanged)
    clearTimeout(this.savedTimer)
    this.state.connected = false
    this.saveTypedValues()
  }

  // The page may be unloaded after this, so nothing can wait: a value waiting for its field's request is sent now.
  flushOnLeave() {
    this.saveTypedValues()

    const state = this.state
    state.waitingValues.forEach((fieldInfo, key) => this.send(state, key, fieldInfo))
    state.waitingValues.clear()
  }

  // A value typed while autosave was on is saved even if it was switched off since, as the pause would have saved it.
  saveTypedValues() {
    const state = this.state
    state.typedValues.forEach(({ timer, fieldInfo }) => {
      clearTimeout(timer)
      this.save(state, fieldInfo)
    })
    state.typedValues.clear()
  }

  toggle() {
    this.active = !this.active
    this.toggleTarget.textContent = this.active
      ? this.toggleTarget.dataset.labelOn
      : this.toggleTarget.dataset.labelOff
    this.toggleTarget.classList.toggle("vm-btn--primary", this.active)
    this.toggleTarget.classList.toggle("vm-btn--ghost", !this.active)
    this.toggleTarget.setAttribute("aria-pressed", String(this.active))
  }

  fieldChanged(event) {
    if (!this.active) return

    const input = event.target
    const fieldInfo = this.parseFieldInfo(input)
    if (!fieldInfo) return

    this.save(this.state, fieldInfo)
  }

  fieldInput(event) {
    if (!this.active) return

    const input = event.target
    const fieldInfo = this.parseFieldInfo(input)
    if (!fieldInfo) return

    const state = this.state
    const key = this.fieldKey(fieldInfo)
    if (state.typedValues.has(key)) clearTimeout(state.typedValues.get(key).timer)
    const timer = setTimeout(() => {
      state.typedValues.delete(key)
      this.save(state, fieldInfo)
    }, 500)
    state.typedValues.set(key, { timer, fieldInfo })
  }

  fieldKey(fieldInfo) {
    return `${fieldInfo.scope}-${fieldInfo.seat || ""}-${fieldInfo.field}`
  }

  parseFieldInfo(input) {
    const name = input.name
    if (!name) return null
    // A field marked to skip is saved only with the whole form.
    if (input.hasAttribute("data-protocol-autosave-skip")) return null

    const gameMatch = name.match(/^game\[(\w+)\]$/)
    if (gameMatch) {
      return { scope: "game", field: gameMatch[1], value: this.inputValue(input) }
    }

    const partMatch = name.match(/^participations\[(\d+)\]\[(\w+)\](\[\])?$/)
    if (partMatch) {
      let value = input.value
      if (partMatch[3]) {
        value = this.listValue(input)
      } else {
        value = this.inputValue(input)
      }
      return { scope: "participation", seat: partMatch[1], field: partMatch[2], value: value }
    }

    return null
  }

  inputValue(input) {
    if (input.type === "checkbox") return input.checked ? "1" : "0"

    return input.value
  }

  // A list field is posted as several inputs sharing one name; autosave sends their filled values together.
  listValue(input) {
    return Array.from(input.form.elements)
      .filter((element) => element.name === input.name && element.value !== "")
      .map((element) => element.value)
  }

  save(state, fieldInfo) {
    this.showStatus(state, "saving")

    const key = this.fieldKey(fieldInfo)
    if (state.requests.has(key)) {
      state.waitingValues.set(key, fieldInfo)
    } else {
      this.send(state, key, fieldInfo)
    }
  }

  async send(state, key, fieldInfo) {
    const body = {
      scope: fieldInfo.scope,
      field: fieldInfo.field,
      value: fieldInfo.value
    }
    if (fieldInfo.seat) {
      body.seat = fieldInfo.seat
    }

    const request = {}
    state.requests.set(key, request)

    // keepalive lets the request finish if the page is unloaded meanwhile.
    const ok = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(body),
      keepalive: true
    }).then(response => response.ok, () => false)
    this.recordResult(state, key, ok)
    // The page may have sent a newer value for this field meanwhile, so only this request's own entry is removed.
    if (state.requests.get(key) === request) state.requests.delete(key)

    this.sendWaitingValue(state, key)
  }

  recordResult(state, key, ok) {
    if (ok) {
      state.failedFields.delete(key)
    } else {
      state.failedFields.add(key)
    }
  }

  sendWaitingValue(state, key) {
    const waiting = state.waitingValues.get(key)
    if (waiting) {
      state.waitingValues.delete(key)
      this.send(state, key, waiting)
    } else if (state.requests.size === 0) {
      this.showStatus(state, state.failedFields.size > 0 ? "error" : "saved")
    }
  }

  // Only the current connection shows its saves.
  showStatus(state, status) {
    if (!state.connected || !this.hasStatusTarget) return

    const target = this.statusTarget
    target.classList.remove("text-ink-muted", "text-gold-ink", "text-alert-ink")
    clearTimeout(this.savedTimer)

    switch (status) {
      case "saving":
        target.textContent = this.savingTextValue
        target.classList.add("text-ink-muted")
        break
      case "saved":
        target.textContent = this.savedTextValue
        target.classList.add("text-gold-ink")
        this.savedTimer = setTimeout(() => {
          target.textContent = ""
        }, 2000)
        break
      case "error":
        target.textContent = this.errorTextValue
        target.classList.add("text-alert-ink")
        break
    }
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
