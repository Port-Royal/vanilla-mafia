import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["parent", "child"]

  connect() {
    this.optionsData = JSON.parse(this.element.dataset.cascadeSelectOptionsValue || "{}")
    this.initialValue = this.childTarget.dataset.selectedValue || ""
    this.updateChild()
  }

  updateChild() {
    const parentId = this.parentTarget.value
    const options = this.optionsData[parentId] || []
    const currentValue = this.initialValue

    this.childTarget.innerHTML = '<option value=""></option>'

    options.forEach(([name, id]) => {
      const option = document.createElement("option")
      option.value = id
      option.textContent = name
      if (String(id) === String(currentValue)) option.selected = true
      this.childTarget.appendChild(option)
    })

    this.childTarget.disabled = options.length === 0
    this.initialValue = ""
  }
}
