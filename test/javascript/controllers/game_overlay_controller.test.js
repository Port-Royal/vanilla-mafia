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

  const cells = () => [...document.querySelectorAll("#overlay-nominees .overlay-night-cell")].map((cell) => [cell.textContent, cell.dataset.colour])
  const block = () => document.getElementById("overlay-nominees")

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay" data-game-overlay-seat-roles-value='{"5":"mafia","3":"peace"}'>
        <div id="overlay-nominees" data-game-overlay-target="nominees" hidden>
          <span data-game-overlay-target="nomineesList"></span>
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

  it("lists the seats in order in their team's colour", () => {
    controller.handleUpdate({ scope: "nominees", seats: [5, 3] })

    expect(cells()).toEqual([["5", "black"], ["3", "red"]])
  })

  it("shows a seat with no known role in a neutral colour", () => {
    controller.handleUpdate({ scope: "nominees", seats: [9] })

    expect(cells()).toEqual([["9", "neutral"]])
  })

  it("shows a seat with a role outside the game's four in a neutral colour", () => {
    controller.handleUpdate({ scope: "participation", seat: 9, field: "role_code", value: "maf" })
    controller.handleUpdate({ scope: "nominees", seats: [9] })

    expect(cells()).toEqual([["9", "neutral"]])
  })

  it("shows the block", () => {
    controller.handleUpdate({ scope: "nominees", seats: [3] })

    expect(block().hidden).toBe(false)
  })

  it("hides the block when the list is empty", () => {
    controller.handleUpdate({ scope: "nominees", seats: [3] })
    controller.handleUpdate({ scope: "nominees", seats: [] })

    expect([block().hidden, cells()]).toEqual([true, []])
  })

  it("recolours a candidate when a role arrives", () => {
    controller.handleUpdate({ scope: "nominees", seats: [9] })
    controller.handleUpdate({ scope: "participation", seat: 9, field: "role_code", value: "don" })

    expect(cells()).toEqual([["9", "black"]])
  })

  it("turns the candidates neutral when roles are hidden", () => {
    controller.handleUpdate({ scope: "nominees", seats: [5, 3] })
    controller.handleUpdate({ scope: "game", field: "hide_roles", value: "1" })

    expect(cells()).toEqual([["5", "neutral"], ["3", "neutral"]])
  })

  it("starts from what the page rendered", async () => {
    application.stop()
    document.getElementById("game-overlay").dataset.gameOverlayNomineesValue = "[3]"
    application = Application.start()
    application.register("game-overlay", GameOverlayController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")
    controller.handleUpdate({ scope: "participation", seat: 3, field: "role_code", value: "sheriff" })

    expect(cells()).toEqual([["3", "red"]])
  })
})

describe("GameOverlayController night block", () => {
  let application
  let controller

  const cells = (name) => [...document.querySelectorAll(`[data-row="${name}"] .overlay-night-cell`)].map((cell) => [cell.textContent, cell.dataset.colour, cell.dataset.mark ?? null])
  const numbers = () => [...document.querySelectorAll(".overlay-night-number")].map((node) => node.textContent)
  const row = (name) => document.querySelector(`[data-row="${name}"]`)
  const block = () => document.getElementById("overlay-night")

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay">
        <div id="overlay-night" data-game-overlay-target="night" hidden>
          <div data-row="nights"><span data-game-overlay-target="nightNumbers"></span></div>
          <div data-row="shots" data-game-overlay-target="shotsRow"><span data-game-overlay-target="shotsCells"></span></div>
          <div data-row="don" data-game-overlay-target="donRow" hidden><span data-game-overlay-target="donCells"></span></div>
          <div data-row="sheriff" data-game-overlay-target="sheriffRow" hidden><span data-game-overlay-target="sheriffCells"></span></div>
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

  const checks = [{ night: 1, kind: "don", target_seat: 2, result: "sheriff" }, { night: 2, kind: "don", target_seat: null, result: null }, { night: 1, kind: "sheriff", target_seat: 4, result: "black" }]

  it("puts each shot in its night with the target's colour and a miss as a cross", () => {
    controller.handleUpdate({ scope: "shots", shots: [{ night: 1, target_seat: 5, team: "red" }, { night: 2, target_seat: null, team: null }] })

    expect(cells("shots")).toEqual([["5", "red", null], ["×", "empty", null]])
  })

  it("numbers the nights", () => {
    controller.handleUpdate({ scope: "shots", shots: [{ night: 2, target_seat: 5, team: null }] })

    expect(numbers()).toEqual(["1", "2"])
  })

  it("keeps the rows aligned by night", () => {
    controller.handleUpdate({ scope: "shots", shots: [{ night: 2, target_seat: 5, team: null }] })

    expect(cells("shots")).toEqual([["", "none", null], ["5", "neutral", null]])
  })

  it("splits the checks into the don's row and the sheriff's row", () => {
    controller.handleUpdate({ scope: "checks", checks })

    expect([cells("don"), cells("sheriff")]).toEqual([
      [["2", "red", "sheriff"], ["×", "empty", null]],
      [["4", "black", null], ["", "none", null]]
    ])
  })

  it("shows a don's check that is not the sheriff in the target's colour", () => {
    controller.handleUpdate({ scope: "checks", checks: [{ night: 1, kind: "don", target_seat: 7, result: "not_sheriff", team: "red" }] })

    expect(cells("don")).toEqual([["7", "red", null]])
  })

  it("shows the don checking his own mafia in black", () => {
    controller.handleUpdate({ scope: "checks", checks: [{ night: 1, kind: "don", target_seat: 3, result: "not_sheriff", team: "black" }] })

    expect(cells("don")).toEqual([["3", "black", null]])
  })

  it("falls back to a neutral colour when the target's team is unknown", () => {
    controller.handleUpdate({ scope: "checks", checks: [{ night: 1, kind: "don", target_seat: 3, result: "not_sheriff", team: null }] })

    expect(cells("don")).toEqual([["3", "neutral", null]])
  })

  it("shows the check rows only with checks", () => {
    controller.handleUpdate({ scope: "checks", checks })

    expect([row("don").hidden, row("sheriff").hidden, block().hidden]).toEqual([false, false, false])
  })

  it("hides the block with nothing recorded", () => {
    controller.handleUpdate({ scope: "checks", checks })
    controller.handleUpdate({ scope: "checks", checks: [] })

    expect([row("don").hidden, block().hidden]).toEqual([true, true])
  })

  it("keeps the shots when roles are hidden and drops the checks", () => {
    controller.handleUpdate({ scope: "shots", shots: [{ night: 1, target_seat: 5, team: null }] })
    controller.handleUpdate({ scope: "checks", checks })
    controller.handleUpdate({ scope: "game", field: "hide_roles", value: "1" })

    expect([cells("shots"), cells("don"), row("sheriff").hidden, block().hidden]).toEqual([[["5", "neutral", null]], [], true, false])
  })

  it("starts from what the page rendered", async () => {
    application.stop()
    document.getElementById("game-overlay").dataset.gameOverlayShotsValue = JSON.stringify([{ night: 1, target_seat: 5, team: null }])
    application = Application.start()
    application.register("game-overlay", GameOverlayController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")
    controller.handleUpdate({ scope: "checks", checks: [{ night: 2, kind: "sheriff", target_seat: 4, result: "red" }] })

    expect(cells("shots")).toEqual([["5", "neutral", null], ["", "none", null]])
  })
})

describe("GameOverlayController role badge colours", () => {
  let application
  let controller

  const badge = () => document.querySelector('[data-game-overlay-target="roleBadge"]')

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay" data-game-overlay-role-badges-value='{"don":"Д","peace":"К"}'>
        <div data-game-overlay-target="roleBadge" data-seat="1"></div>
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

  it("marks the badge with its role", () => {
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: "peace" })

    expect([badge().textContent, badge().dataset.role]).toEqual(["К", "peace"])
  })

  it("drops the mark for a role with no badge", () => {
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: "don" })
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: null })

    expect([badge().textContent, badge().dataset.role]).toEqual(["", undefined])
  })

  it("ignores a seat with no badge on the page", () => {
    expect(() => controller.handleUpdate({ scope: "participation", seat: 9, field: "role_code", value: "peace" })).not.toThrow()
  })

  it("drops the mark when roles are hidden", () => {
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: "don" })
    controller.handleUpdate({ scope: "game", field: "hide_roles", value: "1" })

    expect(badge().dataset.role).toBeUndefined()
  })
})
