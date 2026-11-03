import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import LiveProtocolController from "../../../app/javascript/controllers/live_protocol_controller.js"
import { decide, replay } from "../../../app/javascript/live_protocol/machine.js"

const players = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((seat) => ({ seat, name: `И${seat}`, role_code: null }))
const texts = new Proxy({}, { get: (_target, name) => (name === "seats" ? "" : new Proxy({}, { get: (_t, inner) => `${String(name)}.${String(inner)}` })) })
const actions = [{ type: "assign_roles", seats: [1, 2, 3, 4] }, { type: "finish_deal", mode: "static", seats: [5], text: "план" }]
const events = actions.reduce((list, action) => [...list, ...decide(replay(players, list), action).events], [])
  .map((event, index) => ({ ...event, action_id: `a${index}` }))

class TestController extends LiveProtocolController {
  get textsValue() { return texts }
}

describe("LiveProtocolController scroll positions", () => {
  let application

  const columns = () => document.querySelectorAll(".lp-col")
  const seats = () => columns()[0]
  const side = () => columns()[2]
  const key = (type, code) => document.dispatchEvent(new KeyboardEvent(type, { code, bubbles: true }))
  const clickTab = (name) => document.querySelector(`[data-tab="${name}"]`).click()

  beforeEach(async () => {
    window.localStorage.clear()
    document.body.innerHTML = `<div id="lp" data-controller="live-protocol"
      data-live-protocol-players-value='${JSON.stringify(players)}'
      data-live-protocol-events-value='${JSON.stringify(events)}'
      data-live-protocol-game-id-value="1"
      data-live-protocol-events-url-value="/events"></div>`
    application = Application.start()
    application.register("live-protocol", TestController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("when the log is scrolled and H is held and released", () => {
    beforeEach(() => {
      side().scrollTop = 120
      seats().scrollTop = 30
    })

    it("keeps the log offset while roles are revealed", () => {
      key("keydown", "KeyH")

      expect(side().scrollTop).toBe(120)
    })

    it("re-renders with roles shown", () => {
      key("keydown", "KeyH")

      expect(document.querySelector(".lp-role[data-role]")).not.toBeNull()
    })

    it("keeps the log offset after release", () => {
      key("keydown", "KeyH")
      key("keyup", "KeyH")

      expect(side().scrollTop).toBe(120)
    })

    it("keeps the seat list offset", () => {
      key("keydown", "KeyH")

      expect(seats().scrollTop).toBe(30)
    })
  })

  describe("when switching tabs", () => {
    beforeEach(() => {
      side().scrollTop = 120
      clickTab("sheet")
    })

    it("opens the other tab at its own offset", () => {
      expect(side().scrollTop).toBe(0)
    })

    it("restores the first tab's offset on return", () => {
      side().scrollTop = 40
      clickTab("log")

      expect(side().scrollTop).toBe(120)
    })

    it("remembers the second tab's offset", () => {
      side().scrollTop = 40
      clickTab("log")
      clickTab("sheet")

      expect(side().scrollTop).toBe(40)
    })
  })
})
