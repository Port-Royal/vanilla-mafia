import { Controller } from "@hotwired/stimulus"

// New protocol: game numbers restart every day at every table, so the form asks for the last number
// of the chosen competition, day and table, shows it and prefills the next one. A number the judge
// typed by hand stays; one the form prefilled follows the choices.
export default class extends Controller {
  static targets = ["competition", "stage", "date", "table", "number", "hint"]
  static values = { url: String }

  connect() {
    this.numberTyped()
    this.refresh()
  }

  numberTyped() {
    this.typed = this.numberTarget.value !== ""
  }

  async refresh() {
    // Only the answer to the latest choice counts: a slower earlier one must not win.
    const request = {}
    this.latestRequest = request
    const suggestion = await this.fetchSuggestion()
    if (!suggestion || request !== this.latestRequest) return

    this.hintTarget.textContent = suggestion.hint || ""
    this.hintTarget.hidden = !suggestion.hint
    if (suggestion.next && !this.typed) this.numberTarget.value = suggestion.next
  }

  // The stage select falls back to its competition, so its value is where the game is saved.
  async fetchSuggestion() {
    const params = new URLSearchParams({
      competition_id: this.stageTarget.value || this.competitionTarget.value,
      played_on: this.dateTarget.value,
      table_number: this.tableTarget.value
    })
    try {
      const response = await fetch(`${this.urlValue}?${params}`, { headers: { Accept: "application/json" } })
      return response.ok ? await response.json() : null
    } catch {
      // Offline: the form works without a suggestion.
    }
  }
}
