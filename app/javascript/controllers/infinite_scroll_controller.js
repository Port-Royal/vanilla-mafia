import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel"]

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.loadMore(entry.target)
          }
        })
      },
      { rootMargin: "200px" }
    )

    this.observeSentinels()
  }

  disconnect() {
    this.observer.disconnect()
  }

  sentinelTargetConnected(element) {
    this.observer.observe(element)
  }

  sentinelTargetDisconnected(element) {
    this.observer.unobserve(element)
  }

  loadMore(sentinel) {
    const nextUrl = sentinel.dataset.nextUrl
    if (!nextUrl) return

    this.observer.unobserve(sentinel)
    const loadingMessage = sentinel.dataset.loadingMessage || "Loading..."
    sentinel.innerHTML = `<p class="text-center text-neutral-400 py-4">${loadingMessage}</p>`

    fetch(nextUrl, {
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`${response.status} ${response.statusText}`)
        }
        return response.text()
      })
      .then((html) => {
        sentinel.remove()
        Turbo.renderStreamMessage(html)
      })
      .catch((error) => {
        console.error("Infinite scroll error:", error)
        const errorMessage = sentinel.dataset.errorMessage || "Failed to load. Scroll to retry."
        sentinel.innerHTML = `<p class="text-center text-neutral-400 py-4">${errorMessage}</p>`
        this.observer.observe(sentinel)
      })
  }

  observeSentinels() {
    this.sentinelTargets.forEach((sentinel) => {
      this.observer.observe(sentinel)
    })
  }
}
