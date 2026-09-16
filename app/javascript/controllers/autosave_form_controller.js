import { Controller } from "@hotwired/stimulus"

// Submits the surrounding form as soon as a field changes, so editor panels save inline.
export default class extends Controller {
  static values = { delay: { type: Number, default: 600 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  submit() {
    clearTimeout(this.timer)
    this.element.requestSubmit()
  }

  submitLater() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
