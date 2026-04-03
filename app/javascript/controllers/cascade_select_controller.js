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

    if (!parentId) {
      this.childTarget.innerHTML = '<option value=""></option>'
      this.childTarget.hidden = false
      this.childTarget.disabled = true
      this.initialValue = ""
      return
    }

    if (options.length === 0) {
      this.childTarget.innerHTML = ""
      const fallback = document.createElement("option")
      fallback.value = parentId
      fallback.selected = true
      this.childTarget.appendChild(fallback)
      this.childTarget.hidden = true
    } else {
      this.childTarget.innerHTML = '<option value=""></option>'

      options.forEach(([name, id]) => {
        const option = document.createElement("option")
        option.value = id
        option.textContent = name
        if (String(id) === String(currentValue)) option.selected = true
        this.childTarget.appendChild(option)
      })

      this.childTarget.hidden = false
    }

    this.childTarget.disabled = false
    this.initialValue = ""
  }
}
