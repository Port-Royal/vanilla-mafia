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
    this.debounceTimers = {}
    // One request in flight per field; a value changed meanwhile waits and is sent when it finishes.
    this.requests = new Map()
    this.waitingValues = new Map()
    this.failedFields = new Set()
  }

  disconnect() {
    Object.values(this.debounceTimers).forEach(timer => clearTimeout(timer))
    clearTimeout(this.savedTimer)
    this.requests.forEach(request => request.abort())
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

    this.save(fieldInfo)
  }

  fieldInput(event) {
    if (!this.active) return

    const input = event.target
    const fieldInfo = this.parseFieldInfo(input)
    if (!fieldInfo) return

    const key = this.fieldKey(fieldInfo)
    clearTimeout(this.debounceTimers[key])
    this.debounceTimers[key] = setTimeout(() => this.save(fieldInfo), 500)
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

  save(fieldInfo) {
    this.showStatus("saving")

    const key = this.fieldKey(fieldInfo)
    if (this.requests.has(key)) {
      this.waitingValues.set(key, fieldInfo)
    } else {
      this.send(key, fieldInfo)
    }
  }

  async send(key, fieldInfo) {
    const body = {
      scope: fieldInfo.scope,
      field: fieldInfo.field,
      value: fieldInfo.value
    }
    if (fieldInfo.seat) {
      body.seat = fieldInfo.seat
    }

    const controller = new AbortController()
    this.requests.set(key, controller)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify(body),
        signal: controller.signal
      })

      this.recordResult(key, response.ok)
    } catch {
      this.recordResult(key, false)
    } finally {
      this.requests.delete(key)
    }
    // Aborted on disconnect: nothing to show, and a waiting value is dropped.
    if (controller.signal.aborted) return

    this.sendWaitingValue(key)
  }

  recordResult(key, ok) {
    if (ok) {
      this.failedFields.delete(key)
    } else {
      this.failedFields.add(key)
    }
  }

  sendWaitingValue(key) {
    const waiting = this.waitingValues.get(key)
    if (waiting) {
      this.waitingValues.delete(key)
      this.send(key, waiting)
    } else if (this.requests.size === 0) {
      this.showStatus(this.failedFields.size > 0 ? "error" : "saved")
    }
  }

  showStatus(state) {
    if (!this.hasStatusTarget) return

    const target = this.statusTarget
    target.classList.remove("text-ink-muted", "text-gold-ink", "text-alert-ink")
    clearTimeout(this.savedTimer)

    switch (state) {
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
