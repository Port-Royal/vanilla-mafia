import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async dismiss(event) {
    const ids = event.currentTarget.dataset.announcementIds
    if (!ids) return

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ announcement_ids: ids.split(",") })
    })

    if (response.ok) {
      this.element.remove()
    }
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
