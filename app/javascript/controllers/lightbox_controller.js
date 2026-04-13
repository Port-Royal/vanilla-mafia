import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault()
    const url = this.element.getAttribute("href")
    if (!url) return

    const overlay = document.createElement("div")
    overlay.className = "fixed inset-0 z-50 bg-black/90 flex items-center justify-center cursor-zoom-out p-4"
    overlay.setAttribute("role", "dialog")
    overlay.setAttribute("aria-modal", "true")

    const img = document.createElement("img")
    img.src = url
    img.alt = ""
    img.className = "max-w-full max-h-full object-contain"

    overlay.appendChild(img)
    document.body.appendChild(overlay)
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"

    const close = () => {
      overlay.remove()
      document.body.style.overflow = previousOverflow
      document.removeEventListener("keydown", onKey)
    }
    const onKey = (e) => {
      if (e.key === "Escape") close()
    }

    overlay.addEventListener("click", close)
    document.addEventListener("keydown", onKey)
  }
}
