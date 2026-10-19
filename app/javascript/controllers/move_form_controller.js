import { Controller } from "@hotwired/stimulus"

// Shows the fields the selected move kind needs or may use, plus the text field (optional for most kinds, required for "other"),
// with the kind's hint and any field labels that depend on the kind.
export default class extends Controller {
  static targets = ["kind", "field", "label", "hint"]
  static values = { required: Object, optional: Object, hints: Object, labels: Object }

  connect() {
    this.kindChanged()
  }

  kindChanged() {
    const kind = this.kindTarget.value
    const shown = [...(this.requiredValue[kind] || []), ...(this.optionalValue[kind] || [])]

    this.fieldTargets.forEach((field) => {
      const name = field.dataset.field
      field.hidden = !shown.includes(name) && name !== "text"
    })

    const labels = this.labelsValue[kind] || {}
    this.labelTargets.forEach((label) => {
      label.textContent = labels[label.dataset.field] || label.dataset.defaultLabel
    })

    const hint = this.hintsValue[kind]
    this.hintTarget.textContent = hint || ""
    this.hintTarget.hidden = !hint
  }
}
