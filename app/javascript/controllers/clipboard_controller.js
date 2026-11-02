import { Controller } from "@hotwired/stimulus"

// Copies a field's value, or the text value when there is no field, and confirms on the button once the write succeeds.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { text: String, copied: { type: String, default: "✓" } }

  async copy() {
    const text = this.hasSourceTarget ? this.sourceTarget.value : this.textValue
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      return
    }
    this.label ??= this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedValue
    clearTimeout(this.restoreTimer)
    this.restoreTimer = setTimeout(() => { this.buttonTarget.textContent = this.label }, 2000)
  }

  disconnect() {
    clearTimeout(this.restoreTimer)
  }
}
