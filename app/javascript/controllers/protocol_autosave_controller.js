import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "toggle"]
  static values = {
    gameId: Number,
    url: String,
    savingText: { type: String, default: "..." },
    savedText: { type: String, default: "OK" },
    errorText: { type: String, default: "!" }
  }

  connect() {
    this.active = false
    this.pendingRequest = null
    this.debounceTimers = {}
  }

  disconnect() {
    Object.values(this.debounceTimers).forEach(timer => clearTimeout(timer))
    if (this.pendingRequest) {
      this.pendingRequest.abort()
    }
  }

  toggle() {
    this.active = !this.active
    this.toggleTarget.textContent = this.active
      ? this.toggleTarget.dataset.labelOn
      : this.toggleTarget.dataset.labelOff
    this.toggleTarget.classList.toggle("bg-green-500", this.active)
    this.toggleTarget.classList.toggle("text-white", this.active)
    this.toggleTarget.classList.toggle("bg-gray-200", !this.active)
    this.toggleTarget.classList.toggle("text-gray-700", !this.active)
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

    const key = `${fieldInfo.scope}-${fieldInfo.seat || ""}-${fieldInfo.field}`
    clearTimeout(this.debounceTimers[key])
    this.debounceTimers[key] = setTimeout(() => this.save(fieldInfo), 500)
  }

  parseFieldInfo(input) {
    const name = input.name
    if (!name) return null

    const gameMatch = name.match(/^game\[(\w+)\]$/)
    if (gameMatch) {
      return { scope: "game", field: gameMatch[1], value: input.value }
    }

    const partMatch = name.match(/^participations\[(\d+)\]\[(\w+)\]$/)
    if (partMatch) {
      let value = input.value
      if (input.type === "checkbox") {
        value = input.checked ? "1" : "0"
      }
      return { scope: "participation", seat: partMatch[1], field: partMatch[2], value: value }
    }

    return null
  }

  async save(fieldInfo) {
    this.showStatus("saving")

    const body = {
      scope: fieldInfo.scope,
      field: fieldInfo.field,
      value: fieldInfo.value
    }
    if (fieldInfo.seat) {
      body.seat = fieldInfo.seat
    }

    const controller = new AbortController()
    this.pendingRequest = controller

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

      if (response.ok) {
        this.showStatus("saved")
      } else {
        this.showStatus("error")
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        this.showStatus("error")
      }
    } finally {
      this.pendingRequest = null
    }
  }

  showStatus(state) {
    if (!this.hasStatusTarget) return

    const target = this.statusTarget
    target.classList.remove("text-gray-500", "text-green-600", "text-red-600")

    switch (state) {
      case "saving":
        target.textContent = this.savingTextValue
        target.classList.add("text-gray-500")
        break
      case "saved":
        target.textContent = this.savedTextValue
        target.classList.add("text-green-600")
        clearTimeout(this.savedTimer)
        this.savedTimer = setTimeout(() => {
          target.textContent = ""
        }, 2000)
        break
      case "error":
        target.textContent = this.errorTextValue
        target.classList.add("text-red-600")
        break
    }
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
