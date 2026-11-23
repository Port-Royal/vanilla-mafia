import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import AudioPlayerController from "../../../app/javascript/controllers/audio_player_controller.js"

describe("AudioPlayerController", () => {
  let application
  let fetchMock
  let setPositionState

  const html = `
    <div data-controller="audio-player"
         data-audio-player-play-label-value="Воспроизвести"
         data-audio-player-pause-label-value="Пауза"
         data-audio-player-position-url-value="/position">
      <audio data-audio-player-target="audio"
             data-action="play->audio-player#playing pause->audio-player#paused ended->audio-player#ended"></audio>
      <button data-audio-player-target="playButton" aria-label="Воспроизвести">▶</button>
      <span data-audio-player-target="currentTime">0:00</span>
      <div data-audio-player-target="progress"><div data-audio-player-target="progressBar" style="width: 40%"></div></div>
      <span data-audio-player-target="duration">0:00</span>
      <button data-audio-player-target="speedButton">1x</button>
    </div>
  `

  const audio = () => document.querySelector("audio")
  const playButton = () => document.querySelector("[data-audio-player-target='playButton']")
  const emit = async (type) => {
    audio().dispatchEvent(new Event(type))
    await Promise.resolve()
  }

  beforeEach(async () => {
    vi.useFakeTimers()
    fetchMock = vi.fn(() => Promise.resolve({ ok: true }))
    vi.stubGlobal("fetch", fetchMock)
    setPositionState = vi.fn()
    Object.defineProperty(navigator, "mediaSession", {
      value: { setPositionState, setActionHandler: vi.fn() },
      configurable: true
    })
    document.body.innerHTML = html
    Object.defineProperty(audio(), "duration", { value: 100, configurable: true })
    application = Application.start()
    application.register("audio-player", AudioPlayerController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
    delete navigator.mediaSession
    vi.unstubAllGlobals()
    vi.useRealTimers()
  })

  describe("when playback starts", () => {
    beforeEach(async () => emit("play"))

    it("shows the pause glyph", () => {
      expect(playButton().textContent).toBe("⏸")
    })

    it("labels the button with the pause label", () => {
      expect(playButton().getAttribute("aria-label")).toBe("Пауза")
    })

    it("reports the position to the media session", () => {
      expect(setPositionState).toHaveBeenCalledWith({ duration: 100, playbackRate: 1, position: 0 })
    })

    it("saves the position every ten seconds", () => {
      vi.advanceTimersByTime(10000)

      expect(fetchMock).toHaveBeenCalledTimes(1)
    })
  })

  describe("when playback pauses", () => {
    beforeEach(async () => {
      await emit("play")
      await emit("pause")
    })

    it("shows the play glyph", () => {
      expect(playButton().textContent).toBe("▶")
    })

    it("labels the button with the play label", () => {
      expect(playButton().getAttribute("aria-label")).toBe("Воспроизвести")
    })

    it("saves the position at once", () => {
      expect(fetchMock).toHaveBeenCalledTimes(1)
    })

    it("stops saving every ten seconds", () => {
      vi.advanceTimersByTime(10000)

      expect(fetchMock).toHaveBeenCalledTimes(1)
    })
  })

  describe("when playback ends", () => {
    beforeEach(async () => {
      await emit("play")
      await emit("ended")
    })

    it("resets the progress bar", () => {
      expect(document.querySelector("[data-audio-player-target='progressBar']").style.width).toBe("0%")
    })

    it("shows the play glyph", () => {
      expect(playButton().textContent).toBe("▶")
    })

    it("labels the button with the play label", () => {
      expect(playButton().getAttribute("aria-label")).toBe("Воспроизвести")
    })
  })

  describe("without a position url", () => {
    beforeEach(async () => {
      document.querySelector("[data-controller]").removeAttribute("data-audio-player-position-url-value")
      await Promise.resolve()
      await emit("pause")
    })

    it("does not save the position", () => {
      expect(fetchMock).not.toHaveBeenCalled()
    })
  })
})
