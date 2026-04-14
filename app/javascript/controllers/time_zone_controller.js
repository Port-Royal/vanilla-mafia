import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (this.hasTzCookie()) return

    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!zone) return

    const expires = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toUTCString()
    document.cookie = `tz=${encodeURIComponent(zone)}; expires=${expires}; path=/; SameSite=Lax`
    window.location.reload()
  }

  hasTzCookie() {
    return document.cookie.split("; ").some((c) => c.startsWith("tz="))
  }
}
