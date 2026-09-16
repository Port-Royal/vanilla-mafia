import { Controller } from "@hotwired/stimulus"

// Shows only the fields the selected move kind needs, plus the always-optional comment.
export default class extends Controller {
  static targets = ["kind", "field"]
  static values = { required: Object }

  connect() {
    this.kindChanged()
  }

  kindChanged() {
    const required = this.requiredValue[this.kindTarget.value] || []

    this.fieldTargets.forEach((field) => {
      const name = field.dataset.field
      field.hidden = !required.includes(name) && name !== "text"
    })
  }
}
