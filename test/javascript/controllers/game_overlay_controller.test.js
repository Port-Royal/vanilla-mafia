import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import GameOverlayController from "../../../app/javascript/controllers/game_overlay_controller.js"

vi.mock("@rails/actioncable", () => ({
  createConsumer: () => ({ subscriptions: { create: () => ({ unsubscribe() {} }) } })
}))

describe("GameOverlayController role hiding", () => {
  let application
  let controller

  const badge = (seat) => document.querySelector(`.badge[data-seat="${seat}"]`).textContent
  const colour = () => document.querySelector("[data-named-seat='2']").dataset.colour
  const canvas = () => document.getElementById("game-overlay")

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay"
           data-controller="game-overlay"
           data-game-overlay-role-badges-value='{"don":"Д"}'
           data-game-overlay-seat-roles-value='{"2":"don"}'
           data-game-overlay-best-move-colours-value='{"don":"black"}'>
        <div class="badge" data-game-overlay-target="roleBadge" data-seat="1">Д</div>
        <div class="badge" data-game-overlay-target="roleBadge" data-seat="2">Д</div>
        <div data-game-overlay-target="bestMove" data-seat="1">
          <span data-named-seat="2" data-colour="black">2</span>
        </div>
      </div>
    `
    application = Application.start()
    application.register("game-overlay", GameOverlayController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(canvas(), "game-overlay")
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("when hide_roles turns on", () => {
    beforeEach(() => controller.handleUpdate({ scope: "game", field: "hide_roles", value: "1" }))

    it("hides via the canvas class", () => {
      expect(canvas().classList.contains("overlay-canvas--hide-roles")).toBe(true)
    })

    it("wipes every badge", () => {
      expect([badge(1), badge(2)]).toEqual(["", ""])
    })

    it("paints best move cells neutral", () => {
      expect(colour()).toBe("neutral")
    })

    it("forgets the roles for cells rendered later", () => {
      controller.renderBestMove(1, [2])

      expect(colour()).toBe("neutral")
    })
  })

  describe("when hide_roles turns off", () => {
    beforeEach(() => controller.handleUpdate({ scope: "game", field: "hide_roles", value: "0" }))

    it("keeps the known roles", () => {
      expect([badge(1), colour()]).toEqual(["Д", "black"])
    })

    it("removes the canvas class", () => {
      canvas().classList.add("overlay-canvas--hide-roles")
      controller.handleUpdate({ scope: "game", field: "hide_roles", value: "0" })

      expect(canvas().classList.contains("overlay-canvas--hide-roles")).toBe(false)
    })
  })

  describe("when another display setting turns on", () => {
    beforeEach(() => controller.handleUpdate({ scope: "game", field: "hide_game_info", value: "1" }))

    it("keeps the known roles", () => {
      expect([badge(1), colour()]).toEqual(["Д", "black"])
    })
  })

  describe("when roles are sent after hiding is lifted", () => {
    beforeEach(() => {
      controller.handleUpdate({ scope: "game", field: "hide_roles", value: "1" })
      controller.handleUpdate({ scope: "game", field: "hide_roles", value: "0" })
      controller.handleUpdate({ scope: "participation", seat: 2, field: "role_code", value: "don" })
    })

    it("restores the badge and the colour", () => {
      expect([badge(2), colour()]).toEqual(["Д", "black"])
    })
  })
})

describe("GameOverlayController nominees", () => {
  let application
  let controller

  const names = () => [...document.querySelectorAll("#overlay-nominees .overlay-nominee")].map((node) => node.textContent)
  const block = () => document.getElementById("overlay-nominees")

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay">
        <div data-game-overlay-target="playerName" data-seat="3">Третий</div>
        <div data-game-overlay-target="playerName" data-seat="5">&lt;Пятый&gt;</div>
        <div id="overlay-nominees" data-game-overlay-target="nominees" hidden>
          <span class="overlay-nominees-title">На голосовании</span>
          <div class="overlay-nominees-list" data-game-overlay-target="nomineesList"></div>
        </div>
      </div>
    `
    application = Application.start()
    application.register("game-overlay", GameOverlayController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  it("lists the seats in order with their names", () => {
    controller.handleUpdate({ scope: "nominees", seats: [5, 3] })

    expect(names()).toEqual(["5 <Пятый>", "3 Третий"])
  })

  it("shows the block", () => {
    controller.handleUpdate({ scope: "nominees", seats: [3] })

    expect(block().hidden).toBe(false)
  })

  it("hides the block when the list is empty", () => {
    controller.handleUpdate({ scope: "nominees", seats: [3] })
    controller.handleUpdate({ scope: "nominees", seats: [] })

    expect([block().hidden, names()]).toEqual([true, []])
  })

  it("names an empty seat by its number only", () => {
    controller.handleUpdate({ scope: "nominees", seats: [9] })

    expect(names()).toEqual(["9"])
  })
})
