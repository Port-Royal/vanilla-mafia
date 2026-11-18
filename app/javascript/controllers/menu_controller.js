import { Controller } from "@hotwired/stimulus"

// One instance per menu: the button toggles the nav target, and an instance
// wired to window events closes on Escape or on a click outside its element.
export default class extends Controller {
  static targets = ["nav", "button"]

  toggle() {
    const expanded = this.navTarget.classList.toggle("hidden") === false
    this.buttonTarget.setAttribute("aria-expanded", expanded)
  }

  close() {
    this.navTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }
}
