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

  describe("with requests answered by hand", () => {
    let fetchMock
    let replies

    const field = (name) => document.querySelector(`[name='${name}']`)
    const edit = async (name, value) => {
      field(name).value = value
      field(name).dispatchEvent(new Event("change", { bubbles: true }))
      await Promise.resolve()
    }
    const sent = () => fetchMock.mock.calls.map(([, options]) => JSON.parse(options.body))
    const signals = () => fetchMock.mock.calls.map(([, options]) => options.signal)
    const answer = async (index, reply) => {
      replies[index].resolve(reply)
      await settle()
    }

    beforeEach(() => {
      replies = []
      fetchMock = vi.fn(() => new Promise((resolve, reject) => replies.push({ resolve, reject })))
      vi.stubGlobal("fetch", fetchMock)
      document.querySelector("form").insertAdjacentHTML("beforeend", '<input name="game[notes]" value="">')
      toggle().click()
    })

    describe("when two fields change back to back", () => {
      beforeEach(async () => {
        await edit("game[name]", "Semifinal")
        await edit("game[notes]", "Late start")
      })

      it("sends both fields", () => {
        expect(sent()).toEqual([
          { scope: "game", field: "name", value: "Semifinal" },
          { scope: "game", field: "notes", value: "Late start" }
        ])
      })

      it("does not abort the first request", () => {
        expect(signals()[0].aborted).toBe(false)
      })

      it("keeps the saving text while the second request is in flight", async () => {
        await answer(0, { ok: true })

        expect(status().textContent).toBe("Saving")
      })

      it("shows the saved text once both are saved", async () => {
        await answer(1, { ok: true })
        await answer(0, { ok: true })

        expect(status().textContent).toBe("Saved")
      })

      it("shows the error text when the first fails after the second is saved", async () => {
        await answer(1, { ok: true })
        await answer(0, { ok: false })

        expect(status().textContent).toBe("Failed")
      })

      it("keeps the error text when the second is saved after the first failed", async () => {
        await answer(0, { ok: false })
        await answer(1, { ok: true })

        expect(status().textContent).toBe("Failed")
      })

      it("shows the error text when the first fails on the network", async () => {
        replies[0].reject(new TypeError("Failed to fetch"))
        await settle()
        await answer(1, { ok: true })

        expect(status().textContent).toBe("Failed")
      })
    })

    describe("when a field that failed is saved again", () => {
      beforeEach(async () => {
        await edit("game[name]", "Semifinal")
        await edit("game[notes]", "Late start")
        await answer(0, { ok: false })
        await answer(1, { ok: true })
        await edit("game[name]", "Final")
        await answer(2, { ok: true })
      })

      it("shows the saved text", () => {
        expect(status().textContent).toBe("Saved")
      })
    })

    describe("when one field changes again while its save is in flight", () => {
      beforeEach(async () => {
        await edit("game[name]", "Semifinal")
        await edit("game[name]", "Quarterfinal")
        await edit("game[name]", "Final")
      })

      it("waits for the request in flight", () => {
        expect(sent()).toEqual([{ scope: "game", field: "name", value: "Semifinal" }])
      })

      it("does not abort the request in flight", () => {
        expect(signals()[0].aborted).toBe(false)
      })

      it("then sends only the latest value", async () => {
        await answer(0, { ok: true })

        expect(sent()).toEqual([
          { scope: "game", field: "name", value: "Semifinal" },
          { scope: "game", field: "name", value: "Final" }
        ])
      })

      it("keeps the saving text until the latest value is saved", async () => {
        await answer(0, { ok: true })

        expect(status().textContent).toBe("Saving")
      })

      it("shows the saved text once the latest value is saved", async () => {
        await answer(0, { ok: true })
        await answer(1, { ok: true })

        expect(status().textContent).toBe("Saved")
      })

      it("sends the latest value even if the earlier one failed", async () => {
        await answer(0, { ok: false })

        expect(sent()[1]).toEqual({ scope: "game", field: "name", value: "Final" })
      })

      it("sends nothing more after the latest value", async () => {
        await answer(0, { ok: true })
        await answer(1, { ok: true })

        expect(fetchMock).toHaveBeenCalledTimes(2)
      })
    })

    describe("when the controller disconnects with saves in flight", () => {
      beforeEach(async () => {
        await edit("game[name]", "Semifinal")
        await edit("game[name]", "Final")
        await edit("game[notes]", "Late start")
        document.querySelector("[data-controller]").removeAttribute("data-controller")
        await settle()
      })

      it("aborts every request in flight", () => {
        expect(signals().map((signal) => signal.aborted)).toEqual([true, true])
      })

      it("does not send the waiting value", async () => {
        const abortError = new DOMException("Aborted", "AbortError")
        replies.forEach((reply) => reply.reject(abortError))
        await settle()

        expect(fetchMock).toHaveBeenCalledTimes(2)
      })
    })

    describe("when the controller disconnects just as a reply arrives", () => {
      beforeEach(async () => {
        await edit("game[name]", "Semifinal")
        await edit("game[name]", "Final")
        const element = document.querySelector("[data-controller]")
        replies[0].resolve({ ok: true })
        application.getControllerForElementAndIdentifier(element, "protocol-autosave").disconnect()
        await settle()
      })

      it("does not send the waiting value", () => {
        expect(fetchMock).toHaveBeenCalledTimes(1)
      })
    })

    describe("when seats change the same field back to back", () => {
      beforeEach(async () => {
        document.querySelector("form").insertAdjacentHTML("beforeend",
          '<input name="participations[1][plus]" value=""><input name="participations[2][plus]" value="">')
        await edit("participations[1][plus]", "0.5")
        await edit("participations[2][plus]", "1")
      })

      it("sends both seats", () => {
        expect(sent()).toEqual([
          { scope: "participation", seat: "1", field: "plus", value: "0.5" },
          { scope: "participation", seat: "2", field: "plus", value: "1" }
        ])
      })
    })
  })

  describe("on a field kept out of autosave", () => {
    let fetchMock

    beforeEach(() => {
      fetchMock = vi.fn(() => new Promise(() => {}))
      vi.stubGlobal("fetch", fetchMock)
      document.querySelector("form").insertAdjacentHTML("beforeend",
        '<input name="game[new_stage_name]" value="Final" data-protocol-autosave-skip>')
      document.querySelector("form").setAttribute("data-action",
        "change->protocol-autosave#fieldChanged input->protocol-autosave#fieldInput")
      toggle().click()
    })

    const skipped = () => document.querySelector("[name='game[new_stage_name]']")

    it("does not save it on change", async () => {
      skipped().dispatchEvent(new Event("change", { bubbles: true }))
      await settle()

      expect(fetchMock).not.toHaveBeenCalled()
    })

    it("does not save it while typing", async () => {
      skipped().dispatchEvent(new Event("input", { bubbles: true }))
      vi.advanceTimersByTime(500)
      await settle()

      expect(fetchMock).not.toHaveBeenCalled()
    })

    it("leaves the status empty", async () => {
      skipped().dispatchEvent(new Event("change", { bubbles: true }))
      await settle()

      expect(status().textContent).toBe("")
    })
  })
})
