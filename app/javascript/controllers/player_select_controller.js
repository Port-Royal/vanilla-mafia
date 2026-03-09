import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "search", "menu", "option"]

  connect() {
    this.activeIndex = -1
    this.boundOutsideClick = this.closeOnOutsideClick.bind(this)
    this.boundReposition = this.repositionMenu.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
    window.addEventListener("resize", this.boundReposition)
    window.addEventListener("scroll", this.boundReposition, true)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    window.removeEventListener("resize", this.boundReposition)
    window.removeEventListener("scroll", this.boundReposition, true)
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.repositionMenu()
    this.filter()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()

    this.optionTargets.forEach((option) => {
      const name = option.dataset.playerName.toLowerCase()
      option.classList.toggle("hidden", !name.includes(query))
      option.classList.remove("bg-gray-100")
    })

    this.activeIndex = -1
    this.hiddenTarget.value = this.searchTarget.value
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
    const name = option.dataset.playerName
    this.searchTarget.value = name
    this.hiddenTarget.value = name
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
