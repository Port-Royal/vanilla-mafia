import { Controller } from "@hotwired/stimulus"

// One instance per menu: the button toggles the nav target, and an instance
// wired to window/document events closes on Escape, on a press outside its
// element, when focus leaves it, and before Turbo caches the page.
export default class extends Controller {
  static targets = ["nav", "button"]

  toggle() {
    const expanded = this.navTarget.classList.toggle("hidden") === false
    this.buttonTarget.setAttribute("aria-expanded", expanded)
  }

  close() {
    const hadFocus = this.navTarget.contains(document.activeElement)

    this.navTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    if (hadFocus) this.buttonTarget.focus()
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  closeOnFocusOut(event) {
    const destination = event.relatedTarget
    if (destination === null || this.element.contains(destination)) return

    this.close()
  }
}
