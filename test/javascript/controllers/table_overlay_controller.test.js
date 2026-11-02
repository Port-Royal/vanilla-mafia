import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const cable = vi.hoisted(() => ({ create: null, unsubscribe: null, callbacks: null, params: null }))

vi.mock("@rails/actioncable", () => ({
  createConsumer: () => ({ subscriptions: { create: cable.create } })
}))

import TableOverlayController from "../../../app/javascript/controllers/table_overlay_controller.js"

describe("TableOverlayController", () => {
  let application
  let controller

  const mount = async (gameId) => {
    document.body.innerHTML = `
      <div id="table-overlay"
           data-controller="table-overlay"
           data-table-overlay-table-value="2"
           data-table-overlay-game-id-value="${gameId}"></div>
    `
    application = Application.start()
    application.register("table-overlay", TableOverlayController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.getElementById("table-overlay"), "table-overlay")
    controller.reload = vi.fn()
  }

  beforeEach(() => {
    cable.unsubscribe = vi.fn()
    cable.create = vi.fn((params, callbacks) => {
      cable.params = params
      cable.callbacks = callbacks
      return { unsubscribe: cable.unsubscribe }
    })
  })

  afterEach(() => {
    if (application) application.stop()
    document.body.innerHTML = ""
  })

  describe("with a game on screen", () => {
    beforeEach(async () => { await mount("7") })

    it("listens to its table", () => {
      expect(cable.params).toEqual({ channel: "TableOverlayChannel", table: 2 })
    })

    it("reloads when another game becomes current", () => {
      cable.callbacks.received({ game_id: 8 })

      expect(controller.reload).toHaveBeenCalledOnce()
    })

    it("stays when the same game is still current", () => {
      cable.callbacks.received({ game_id: 7 })

      expect(controller.reload).not.toHaveBeenCalled()
    })

    it("reloads when the table empties", () => {
      cable.callbacks.received({ game_id: null })

      expect(controller.reload).toHaveBeenCalledOnce()
    })

    it("stops listening when disconnected", async () => {
      document.getElementById("table-overlay").remove()
      await Promise.resolve()

      expect(cable.unsubscribe).toHaveBeenCalledOnce()
    })
  })

  describe("with an empty table", () => {
    beforeEach(async () => { await mount("") })

    it("stays when the table is still empty", () => {
      cable.callbacks.received({ game_id: null })

      expect(controller.reload).not.toHaveBeenCalled()
    })

    it("reloads when a game starts", () => {
      cable.callbacks.received({ game_id: 3 })

      expect(controller.reload).toHaveBeenCalledOnce()
    })
  })

  describe("when the subscription is restored after a lost connection", () => {
    beforeEach(async () => { await mount("7") })

    it("reloads to catch a game that started meanwhile", () => {
      cable.callbacks.connected()
      cable.callbacks.connected()

      expect(controller.reload).toHaveBeenCalledOnce()
    })
  })
})
