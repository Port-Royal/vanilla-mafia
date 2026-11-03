import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import NextGameNumberController from "../../../app/javascript/controllers/next_game_number_controller.js"

const reply = (body, ok = true) => Promise.resolve({ ok, json: () => Promise.resolve(body) })
const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("NextGameNumberController", () => {
  let application
  let fetchMock

  const el = (id) => document.getElementById(id)
  const requestedParams = (call = -1) => new URL(fetchMock.mock.calls.at(call)[0], "http://test").searchParams
  // Stimulus listens to a select's change and an input's input by default, as the form's actions do.
  const change = (id, value) => {
    el(id).value = value
    el(id).dispatchEvent(new Event(el(id).tagName === "SELECT" ? "change" : "input"))
  }
  const type = (value) => {
    el("number").value = value
    el("number").dispatchEvent(new Event("input"))
  }

  const mount = async ({ number = "", stage = "" } = {}) => {
    document.body.innerHTML = `
      <div data-controller="next-game-number" data-next-game-number-url-value="/judge/protocols/next_game_number">
        <select id="competition" data-next-game-number-target="competition" data-action="next-game-number#refresh">
          <option value=""></option><option value="7" selected>Cup</option><option value="8">League</option>
        </select>
        <select id="stage" data-next-game-number-target="stage" data-action="next-game-number#refresh">
          <option value="${stage}" selected></option><option value="9">Final</option>
        </select>
        <input id="number" type="number" value="${number}" data-next-game-number-target="number" data-action="input->next-game-number#numberTyped">
        <p id="hint" data-next-game-number-target="hint" hidden></p>
        <input id="table" type="number" value="2" data-next-game-number-target="table" data-action="next-game-number#refresh">
        <input id="date" type="date" value="2026-11-03" data-next-game-number-target="date" data-action="next-game-number#refresh">
      </div>
    `
    application = Application.start()
    application.register("next-game-number", NextGameNumberController)
    await flush()
  }

  beforeEach(() => {
    fetchMock = vi.fn(() => reply({ last: 4, next: 5, hint: "Last game: #4" }))
    vi.stubGlobal("fetch", fetchMock)
  })

  afterEach(() => {
    application.stop()
    vi.unstubAllGlobals()
    document.body.innerHTML = ""
  })

  describe("on load", () => {
    beforeEach(() => mount())

    it("asks for the competition, the day and the table of the form", () => {
      expect([...requestedParams().entries()]).toEqual([
        ["competition_id", "7"], ["played_on", "2026-11-03"], ["table_number", "2"]
      ])
    })

    it("asks the lookup URL for JSON", () => {
      expect(fetchMock.mock.calls[0][0]).toMatch(/^\/judge\/protocols\/next_game_number\?/)
      expect(fetchMock.mock.calls[0][1]).toEqual({ headers: { Accept: "application/json" } })
    })

    it("prefills the next number", () => {
      expect(el("number").value).toBe("5")
    })

    it("shows the hint", () => {
      expect([el("hint").textContent, el("hint").hidden]).toEqual(["Last game: #4", false])
    })
  })

  describe("with a stage chosen", () => {
    beforeEach(() => mount({ stage: "9" }))

    it("asks for the stage, where the game is saved", () => {
      expect(requestedParams().get("competition_id")).toBe("9")
    })
  })

  describe("when the table has no games yet", () => {
    beforeEach(async () => {
      fetchMock.mockImplementation(() => reply({ last: null, next: 1, hint: null }))
      await mount()
    })

    it("prefills 1", () => {
      expect(el("number").value).toBe("1")
    })

    it("hides the hint", () => {
      expect([el("hint").textContent, el("hint").hidden]).toEqual(["", true])
    })
  })

  describe("when the server suggests nothing", () => {
    beforeEach(async () => {
      fetchMock.mockImplementation(() => reply({ last: null, next: null, hint: null }))
      await mount()
    })

    it("leaves the number empty", () => {
      expect(el("number").value).toBe("")
    })
  })

  describe("when a prefilled choice stops having a suggestion", () => {
    beforeEach(async () => {
      await mount()
      fetchMock.mockImplementation(() => reply({ last: null, next: null, hint: null }))
      change("date", "")
      await flush()
    })

    it("clears the prefilled number", () => {
      expect(el("number").value).toBe("")
    })
  })

  describe("when a typed choice stops having a suggestion", () => {
    beforeEach(async () => {
      await mount()
      type("8")
      fetchMock.mockImplementation(() => reply({ last: null, next: null, hint: null }))
      change("date", "")
      await flush()
    })

    it("keeps the typed number", () => {
      expect(el("number").value).toBe("8")
    })
  })

  describe("when the form already holds a number", () => {
    beforeEach(() => mount({ number: "12" }))

    it("keeps it", () => {
      expect(el("number").value).toBe("12")
    })

    it("still shows the hint", () => {
      expect(el("hint").hidden).toBe(false)
    })
  })

  describe("when the table changes", () => {
    beforeEach(async () => {
      await mount()
      fetchMock.mockImplementation(() => reply({ last: null, next: 1, hint: null }))
      change("table", "3")
      await flush()
    })

    it("asks again for the new table", () => {
      expect([fetchMock.mock.calls.length, requestedParams().get("table_number")]).toEqual([2, "3"])
    })

    it("replaces a prefilled number", () => {
      expect(el("number").value).toBe("1")
    })

    it("clears the old hint", () => {
      expect([el("hint").textContent, el("hint").hidden]).toEqual(["", true])
    })
  })

  describe("when the judge typed a number by hand", () => {
    beforeEach(async () => {
      await mount()
      type("8")
      change("date", "2026-11-04")
      await flush()
    })

    it("does not overwrite it", () => {
      expect(el("number").value).toBe("8")
    })
  })

  describe("when the judge cleared the number", () => {
    beforeEach(async () => {
      await mount()
      type("8")
      type("")
      change("competition", "8")
      await flush()
    })

    it("prefills it again", () => {
      expect(el("number").value).toBe("5")
    })
  })

  describe("when answers come back out of order", () => {
    beforeEach(async () => {
      fetchMock.mockImplementation(() => reply({ last: null, next: 1, hint: null }))
      await mount()
      let releaseSlow
      fetchMock
        .mockImplementationOnce(() => new Promise((resolve) => { releaseSlow = resolve }))
        .mockImplementationOnce(() => reply({ last: 2, next: 3, hint: "Last game: #2" }))
      change("table", "3")
      change("table", "4")
      await flush()
      releaseSlow({ ok: true, json: () => Promise.resolve({ last: 6, next: 7, hint: "Last game: #6" }) })
      await flush()
    })

    it("keeps the answer for the latest choice", () => {
      expect([el("number").value, el("hint").textContent]).toEqual(["3", "Last game: #2"])
    })
  })

  describe("when the server refuses", () => {
    beforeEach(async () => {
      fetchMock.mockImplementation(() => reply({ next: 9, hint: "nope" }, false))
      await mount()
    })

    it("leaves the form alone", () => {
      expect([el("number").value, el("hint").hidden]).toEqual(["", true])
    })
  })

  describe("when the network fails", () => {
    beforeEach(async () => {
      fetchMock.mockImplementation(() => Promise.reject(new TypeError("offline")))
      await mount()
    })

    it("leaves the form alone", () => {
      expect([el("number").value, el("hint").hidden]).toEqual(["", true])
    })
  })
})
