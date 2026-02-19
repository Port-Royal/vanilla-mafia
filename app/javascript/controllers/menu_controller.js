import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "button"]

  toggle() {
    const expanded = this.navTarget.classList.toggle("hidden") === false
    this.buttonTarget.setAttribute("aria-expanded", expanded)
  }
}
