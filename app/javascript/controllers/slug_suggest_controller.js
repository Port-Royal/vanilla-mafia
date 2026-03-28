import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String }

  suggest() {
    const slugInput = document.getElementById(this.targetValue)
    if (!slugInput) return
    if (slugInput.dataset.slugEdited === "true") return

    slugInput.value = this.parameterize(this.element.value)
  }

  parameterize(str) {
    return str
      .toLowerCase()
      .replace(/[^\p{L}\p{N}]+/gu, "-")
      .replace(/^-+|-+$/g, "")
  }
}
