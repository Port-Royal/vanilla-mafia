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
    savedPosition: { type: Number, default: 0 },
    episodeTitle: { type: String, default: "" },
    positionUrl: { type: String, default: "" }
  }

  connect() {
    this.speedIndex = 0
    this.seeking = false
    this.saveTimer = null
    this.boundBeforeUnload = () => this.savePosition()
    window.addEventListener("beforeunload", this.boundBeforeUnload)
  }

  disconnect() {
    this.stopAutoSave()
    window.removeEventListener("beforeunload", this.boundBeforeUnload)
  }

  audioLoaded() {
    this.durationTarget.textContent = this.formatTime(this.audioTarget.duration)

    if (this.savedPositionValue > 0) {
      this.audioTarget.currentTime = this.savedPositionValue
    }

    this.updateProgressUI()
    this.setupMediaSession()
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
    this.updateMediaPositionState()
    this.startAutoSave()
  }

  paused() {
    this.playButtonTarget.textContent = "▶"
    this.playButtonTarget.setAttribute("aria-label", "Play")
    this.stopAutoSave()
    this.savePosition()
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
    this.updateMediaPositionState()
  }

  ended() {
    this.playButtonTarget.textContent = "▶"
    this.playButtonTarget.setAttribute("aria-label", "Play")
    this.progressBarTarget.style.width = "0%"
    this.currentTimeTarget.textContent = this.formatTime(0)
    this.stopAutoSave()
    this.savePosition()
  }

  setupMediaSession() {
    if (!("mediaSession" in navigator)) return

    navigator.mediaSession.metadata = new MediaMetadata({
      title: this.episodeTitleValue
    })

    navigator.mediaSession.setActionHandler("play", () => {
      if (this.audioTarget.paused) {
        this.togglePlay()
      }
    })
    navigator.mediaSession.setActionHandler("pause", () => {
      if (!this.audioTarget.paused) {
        this.togglePlay()
      }
    })
    navigator.mediaSession.setActionHandler("seekbackward", (details) => {
      const current = this.audioTarget.currentTime
      if (!Number.isFinite(current)) return

      const offset = details && Number.isFinite(details.seekOffset) ? details.seekOffset : 10
      this.audioTarget.currentTime = Math.max(0, current - offset)
      this.updateProgressUI()
      this.updateMediaPositionState()
    })
    navigator.mediaSession.setActionHandler("seekforward", (details) => {
      const current = this.audioTarget.currentTime
      const duration = this.audioTarget.duration
      if (!Number.isFinite(current)) return

      const offset = details && Number.isFinite(details.seekOffset) ? details.seekOffset : 10
      let target = current + offset

      if (Number.isFinite(duration) && duration > 0) {
        target = Math.min(target, duration)
      }

      this.audioTarget.currentTime = target
      this.updateProgressUI()
      this.updateMediaPositionState()
    })
    navigator.mediaSession.setActionHandler("seekto", (details) => {
      const seekTime = details && Number.isFinite(details.seekTime) ? details.seekTime : null
      if (seekTime === null) return

      const duration = this.audioTarget.duration
      let target = seekTime

      if (Number.isFinite(duration) && duration > 0) {
        target = Math.min(Math.max(0, target), duration)
      } else {
        target = Math.max(0, target)
      }

      this.audioTarget.currentTime = target
      this.updateProgressUI()
      this.updateMediaPositionState()
    })
  }

  updateMediaPositionState() {
    if (!("mediaSession" in navigator)) return
    if (!navigator.mediaSession.setPositionState) return

    const duration = this.audioTarget.duration
    if (!Number.isFinite(duration) || duration <= 0) return

    navigator.mediaSession.setPositionState({
      duration: duration,
      playbackRate: this.audioTarget.playbackRate,
      position: this.audioTarget.currentTime
    })
  }

  startAutoSave() {
    if (this.saveTimer) return
    this.saveTimer = setInterval(() => this.savePosition(), 10000)
  }

  stopAutoSave() {
    if (this.saveTimer) {
      clearInterval(this.saveTimer)
      this.saveTimer = null
    }
  }

  savePosition() {
    if (!this.positionUrlValue) return

    const position = Math.floor(this.audioTarget.currentTime)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.positionUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ position_seconds: position }),
      keepalive: true
    }).catch(() => {})
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
