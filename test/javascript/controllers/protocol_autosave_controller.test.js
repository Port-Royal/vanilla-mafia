import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ProtocolAutosaveController from "../../../app/javascript/controllers/protocol_autosave_controller.js"

describe("ProtocolAutosaveController", () => {
  let application

  const html = `
    <div data-controller="protocol-autosave"
         data-protocol-autosave-url-value="/autosave"
         data-protocol-autosave-saving-text-value="Saving"
         data-protocol-autosave-saved-text-value="Saved"
         data-protocol-autosave-error-text-value="Failed">
      <span data-protocol-autosave-target="status"></span>
      <button type="button" data-protocol-autosave-target="toggle"
              data-action="click->protocol-autosave#toggle"
              data-label-on="Autosave on" data-label-off="Autosave off"
              aria-pressed="false" class="vm-btn vm-btn--ghost">Autosave off</button>
      <form data-action="change->protocol-autosave#fieldChanged">
        <input name="game[name]" value="Final">
      </form>
    </div>
  `

  const toggle = () => document.querySelector("[data-protocol-autosave-target='toggle']")
  const status = () => document.querySelector("[data-protocol-autosave-target='status']")
  const classes = (element) => Array.from(element.classList)
  const change = async () => {
    document.querySelector("input").dispatchEvent(new Event("change", { bubbles: true }))
    await Promise.resolve()
  }
  const settle = async () => {
    for (let i = 0; i < 5; i++) await Promise.resolve()
  }

  beforeEach(async () => {
    vi.useFakeTimers()
    document.body.innerHTML = html
    application = Application.start()
    application.register("protocol-autosave", ProtocolAutosaveController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
    vi.unstubAllGlobals()
    vi.useRealTimers()
  })

  describe("when switched on", () => {
    beforeEach(() => toggle().click())

    it("shows the on label", () => {
      expect(toggle().textContent).toBe("Autosave on")
    })

    it("draws the toggle as a primary button", () => {
      expect(classes(toggle())).toEqual(["vm-btn", "vm-btn--primary"])
    })

    it("announces the toggle as pressed", () => {
      expect(toggle().getAttribute("aria-pressed")).toBe("true")
    })
  })

  describe("when switched on and off again", () => {
    beforeEach(() => {
      toggle().click()
      toggle().click()
    })

    it("shows the off label", () => {
      expect(toggle().textContent).toBe("Autosave off")
    })

    it("draws the toggle as a ghost button", () => {
      expect(classes(toggle())).toEqual(["vm-btn", "vm-btn--ghost"])
    })

    it("announces the toggle as not pressed", () => {
      expect(toggle().getAttribute("aria-pressed")).toBe("false")
    })
  })

  describe("while a save is in flight", () => {
    beforeEach(async () => {
      vi.stubGlobal("fetch", vi.fn(() => new Promise(() => {})))
      toggle().click()
      await change()
    })

    it("shows the saving text", () => {
      expect(status().textContent).toBe("Saving")
    })

    it("colours the status muted", () => {
      expect(classes(status())).toEqual(["text-ink-muted"])
    })
  })

  describe("after a successful save", () => {
    beforeEach(async () => {
      vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ ok: true })))
      toggle().click()
      await change()
      await settle()
    })

    it("shows the saved text", () => {
      expect(status().textContent).toBe("Saved")
    })

    it("colours the status gold", () => {
      expect(classes(status())).toEqual(["text-gold-ink"])
    })

    it("clears the saved text after two seconds", () => {
      vi.advanceTimersByTime(2000)

      expect(status().textContent).toBe("")
    })
  })

  describe("when a new save starts before the saved text clears", () => {
    beforeEach(async () => {
      vi.stubGlobal("fetch", vi.fn()
        .mockImplementationOnce(() => Promise.resolve({ ok: true }))
        .mockImplementationOnce(() => new Promise(() => {})))
      toggle().click()
      await change()
      await settle()
      await change()
      vi.advanceTimersByTime(2000)
    })

    it("keeps the saving text", () => {
      expect(status().textContent).toBe("Saving")
    })
  })

  describe("after a failed save", () => {
    beforeEach(async () => {
      vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ ok: false })))
      toggle().click()
      await change()
      await settle()
    })

    it("shows the error text", () => {
      expect(status().textContent).toBe("Failed")
    })

    it("colours the status as an alert", () => {
      expect(classes(status())).toEqual(["text-alert-ink"])
    })
  })

  describe("after a failed save followed by a successful one", () => {
    beforeEach(async () => {
      vi.stubGlobal("fetch", vi.fn()
        .mockImplementationOnce(() => Promise.resolve({ ok: false }))
        .mockImplementationOnce(() => Promise.resolve({ ok: true })))
      toggle().click()
      await change()
      await settle()
      await change()
      await settle()
    })

    it("keeps only the saved colour", () => {
      expect(classes(status())).toEqual(["text-gold-ink"])
    })
  })

  describe("without a status target", () => {
    let fetchMock

    beforeEach(async () => {
      fetchMock = vi.fn(() => new Promise(() => {}))
      vi.stubGlobal("fetch", fetchMock)
      status().remove()
      toggle().click()
      await change()
    })

    it("still saves the field", () => {
      expect(fetchMock).toHaveBeenCalledTimes(1)
    })
  })
})
