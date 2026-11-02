import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ClipboardController from "../../../app/javascript/controllers/clipboard_controller.js"

describe("ClipboardController", () => {
  let application
  let writeText

  const mount = async (html) => {
    document.body.innerHTML = html
    application = Application.start()
    application.register("clipboard", ClipboardController)
    await Promise.resolve()
  }

  const button = () => document.querySelector("button")
  const click = async () => {
    button().click()
    await Promise.resolve()
    await Promise.resolve()
  }

  beforeEach(() => {
    vi.useFakeTimers()
    writeText = vi.fn(() => Promise.resolve())
    Object.defineProperty(navigator, "clipboard", { value: { writeText }, configurable: true })
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
    vi.useRealTimers()
  })

  describe("with a source field", () => {
    beforeEach(async () => {
      await mount(`
        <div data-controller="clipboard">
          <input data-clipboard-target="source" value="https://example.test/feed">
          <button data-action="click->clipboard#copy" data-clipboard-target="button">Copy</button>
        </div>
      `)
    })

    it("copies the field value", async () => {
      await click()

      expect(writeText).toHaveBeenCalledWith("https://example.test/feed")
    })

    it("confirms with a check mark by default", async () => {
      await click()

      expect(button().textContent).toBe("✓")
    })

    it("restores the label after two seconds", async () => {
      await click()
      vi.advanceTimersByTime(1999)
      expect(button().textContent).toBe("✓")

      vi.advanceTimersByTime(1)
      expect(button().textContent).toBe("Copy")
    })
  })

  describe("with the text and confirmation given as values", () => {
    beforeEach(async () => {
      await mount(`
        <div data-controller="clipboard"
             data-clipboard-text-value="https://example.test/overlay"
             data-clipboard-copied-value="Copied">
          <button data-action="click->clipboard#copy" data-clipboard-target="button">Copy link</button>
        </div>
      `)
    })

    it("copies the text value", async () => {
      await click()

      expect(writeText).toHaveBeenCalledWith("https://example.test/overlay")
    })

    it("confirms with the given text", async () => {
      await click()

      expect(button().textContent).toBe("Copied")
    })

    it("restores the label after two seconds", async () => {
      await click()
      vi.advanceTimersByTime(2000)

      expect(button().textContent).toBe("Copy link")
    })

    it("stops the pending restore when the controller disconnects", async () => {
      await click()
      const detached = button()
      document.querySelector("[data-controller]").remove()
      await Promise.resolve()
      vi.advanceTimersByTime(2000)

      expect(detached.textContent).toBe("Copied")
    })

    it("restores the original label two seconds after a second click", async () => {
      await click()
      vi.advanceTimersByTime(1000)
      await click()
      vi.advanceTimersByTime(1999)
      expect(button().textContent).toBe("Copied")

      vi.advanceTimersByTime(1)
      expect(button().textContent).toBe("Copy link")
    })
  })

  describe("when the clipboard refuses the write", () => {
    beforeEach(async () => {
      writeText.mockImplementation(() => Promise.reject(new Error("denied")))
      await mount(`
        <div data-controller="clipboard" data-clipboard-text-value="x" data-clipboard-copied-value="Copied">
          <button data-action="click->clipboard#copy" data-clipboard-target="button">Copy link</button>
        </div>
      `)
    })

    it("keeps the label", async () => {
      await click()

      expect(button().textContent).toBe("Copy link")
    })
  })
})
