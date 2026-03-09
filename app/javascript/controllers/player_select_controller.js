import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "menu", "option"]

  static _ensureGlobalState() {
    if (!this._initialized) {
      this.instances = new Set()
      this.globalListenersAttached = false
      this.handleDocumentClick = (event) => {
        for (const controller of this.instances) {
          controller.closeOnOutsideClick(event)
        }
      }
      this.handleReposition = () => {
        for (const controller of this.instances) {
          controller.repositionMenu()
        }
      }
      this._initialized = true
    }
  }

  connect() {
    this.constructor._ensureGlobalState()
    this.constructor.instances.add(this)

    if (!this.constructor.globalListenersAttached) {
      document.addEventListener("click", this.constructor.handleDocumentClick)
      window.addEventListener("resize", this.constructor.handleReposition)
      window.addEventListener("scroll", this.constructor.handleReposition, true)
      this.constructor.globalListenersAttached = true
    }

    this.activeIndex = -1
    this.populateOptions()
  }

  populateOptions() {
    const template = document.getElementById("player-options")
    if (template) {
      this.menuTarget.appendChild(template.content.cloneNode(true))
    }
  }

  disconnect() {
    this.constructor.instances.delete(this)

    if (this.constructor.instances.size === 0 && this.constructor.globalListenersAttached) {
      document.removeEventListener("click", this.constructor.handleDocumentClick)
      window.removeEventListener("resize", this.constructor.handleReposition)
      window.removeEventListener("scroll", this.constructor.handleReposition, true)
      this.constructor.globalListenersAttached = false
    }
  }

  open() {
    this.cancelClose()
    this.menuTarget.classList.remove("hidden")
    this.filter()
    this.repositionMenu()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()

    this.optionTargets.forEach((option) => {
      const name = option.dataset.playerName.toLowerCase()
      option.classList.toggle("hidden", !name.includes(query))
      option.classList.remove("bg-gray-100")
    })

    this.activeIndex = -1
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      return
    }

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.open()
      this.move(1)
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.open()
      this.move(-1)
      return
    }

    if (event.key === "Enter" && this.isOpen()) {
      event.preventDefault()
      const options = this.visibleOptions()
      if (options.length === 0) {
        this.close()
        return
      }

      const option = this.activeIndex >= 0 ? options[this.activeIndex] : options[0]
      this.pick(option)
    }
  }

  hover(event) {
    const options = this.visibleOptions()
    const hoveredIndex = options.indexOf(event.currentTarget)
    if (hoveredIndex >= 0) {
      this.highlight(hoveredIndex)
    }
  }

  select(event) {
    event.preventDefault()
    this.pick(event.currentTarget)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.activeIndex = -1
    this.optionTargets.forEach((option) => option.classList.remove("bg-gray-100"))
  }

  scheduleClose() {
    this._blurTimeout = setTimeout(() => this.close(), 150)
  }

  cancelClose() {
    if (this._blurTimeout) {
      clearTimeout(this._blurTimeout)
      this._blurTimeout = null
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  visibleOptions() {
    return this.optionTargets.filter((option) => !option.classList.contains("hidden"))
  }

  move(step) {
    const options = this.visibleOptions()
    if (options.length === 0) {
      return
    }

    const nextIndex = this.activeIndex < 0 ? (step > 0 ? 0 : options.length - 1) : (this.activeIndex + step + options.length) % options.length
    this.highlight(nextIndex)
  }

  highlight(index) {
    const options = this.visibleOptions()
    options.forEach((option) => option.classList.remove("bg-gray-100"))

    const active = options[index]
    if (!active) {
      this.activeIndex = -1
      return
    }

    active.classList.add("bg-gray-100")
    active.scrollIntoView({ block: "nearest" })
    this.activeIndex = index
  }

  pick(option) {
    this.cancelClose()
    const name = option.dataset.playerName
    this.searchTarget.value = name
    this.close()
  }

  repositionMenu() {
    if (this.menuTarget.classList.contains("hidden")) {
      return
    }

    const inputRect = this.searchTarget.getBoundingClientRect()
    const widestOption = this.visibleOptions().reduce((maxWidth, option) => {
      return Math.max(maxWidth, option.scrollWidth)
    }, 0)
    const desiredWidth = Math.max(inputRect.width, widestOption)
    const viewportMaxWidth = window.innerWidth - inputRect.left - 8
    const contentMaxWidth = 360
    const maxWidth = Math.min(viewportMaxWidth, contentMaxWidth)
    const finalWidth = Math.max(inputRect.width, Math.min(desiredWidth, maxWidth))

    this.menuTarget.style.left = `${inputRect.left}px`
    this.menuTarget.style.top = `${inputRect.bottom + 4}px`
    this.menuTarget.style.width = `${finalWidth}px`
  }
}
