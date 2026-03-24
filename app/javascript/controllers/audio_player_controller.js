import { Controller } from "@hotwired/stimulus"

const SPEEDS = [1, 1.25, 1.5, 1.75, 2]

export default class extends Controller {
  static targets = [
    "audio",
    "playButton",
    "progress",
    "progressBar",
    "currentTime",
    "duration",
    "speedButton"
  ]

  static values = {
    savedPosition: { type: Number, default: 0 }
  }

  connect() {
    this.speedIndex = 0
    this.seeking = false
  }

  audioLoaded() {
    this.durationTarget.textContent = this.formatTime(this.audioTarget.duration)

    if (this.savedPositionValue > 0) {
      this.audioTarget.currentTime = this.savedPositionValue
    }

    this.updateProgressUI()
  }

  togglePlay() {
    if (this.audioTarget.paused) {
      const promise = this.audioTarget.play()
      if (promise) {
        promise.catch(() => {})
      }
    } else {
      this.audioTarget.pause()
    }
  }

  playing() {
    this.playButtonTarget.textContent = "⏸"
    this.playButtonTarget.setAttribute("aria-label", "Pause")
  }

  paused() {
    this.playButtonTarget.textContent = "▶"
    this.playButtonTarget.setAttribute("aria-label", "Play")
  }

  timeUpdate() {
    if (this.seeking) return
    this.updateProgressUI()
  }

  seek(event) {
    const duration = this.audioTarget.duration

    if (!Number.isFinite(duration) || duration <= 0) {
      return
    }

    const clientX = event.touches ? event.touches[0].clientX : event.clientX
    const rect = this.progressTarget.getBoundingClientRect()
    const percent = (clientX - rect.left) / rect.width
    const clampedPercent = Math.max(0, Math.min(1, percent))
    this.audioTarget.currentTime = clampedPercent * duration
    this.updateProgressUI()
  }

  seekStart(event) {
    this.seeking = true
    this.seek(event)
  }

  seekMove(event) {
    if (!this.seeking) return
    this.seek(event)
  }

  seekEnd() {
    this.seeking = false
  }

  seekKeyboard(event) {
    const duration = this.audioTarget.duration

    if (!Number.isFinite(duration) || duration <= 0) {
      return
    }

    const step = duration * 0.05
    let handled = true

    switch (event.key) {
      case "ArrowLeft":
        this.audioTarget.currentTime = Math.max(0, this.audioTarget.currentTime - step)
        break
      case "ArrowRight":
        this.audioTarget.currentTime = Math.min(duration, this.audioTarget.currentTime + step)
        break
      default:
        handled = false
    }

    if (handled) {
      event.preventDefault()
      this.updateProgressUI()
    }
  }

  cycleSpeed() {
    this.speedIndex = (this.speedIndex + 1) % SPEEDS.length
    const speed = SPEEDS[this.speedIndex]
    this.audioTarget.playbackRate = speed
    this.speedButtonTarget.textContent = `${speed}x`
  }

  ended() {
    this.playButtonTarget.textContent = "▶"
    this.playButtonTarget.setAttribute("aria-label", "Play")
    this.progressBarTarget.style.width = "0%"
    this.currentTimeTarget.textContent = this.formatTime(0)
  }

  updateProgressUI() {
    const current = this.audioTarget.currentTime
    const duration = this.audioTarget.duration

    this.currentTimeTarget.textContent = this.formatTime(current)

    if (duration > 0) {
      const percent = (current / duration) * 100
      this.progressBarTarget.style.width = `${percent}%`
      this.progressTarget.setAttribute("aria-valuenow", Math.round(percent))
    }
  }

  formatTime(seconds) {
    if (!isFinite(seconds)) return "0:00"

    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}
