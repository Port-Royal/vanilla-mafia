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

describe("GameOverlayController name fitting", () => {
  let application
  let controller

  // jsdom lays nothing out, so each name's text is 10px wide per character at its fitted size, in a
  // bar 110px wide with 10px of padding: ten characters fill it exactly, eleven need 0.9, and more
  // than sixteen cannot fit even at 0.6.
  let charWidth
  const fit = (seat) => nameOf(seat).style.getPropertyValue("--overlay-name-fit")
  const nameOf = (seat) => document.querySelector(`[data-game-overlay-target="playerName"][data-seat="${seat}"]`)
  const fitOf = (name) => Number(name.style.getPropertyValue("--overlay-name-fit") || 1)
  const layOut = (name) => {
    name.getBoundingClientRect = () => ({ width: 110 })
  }
  const start = async () => {
    application = Application.start()
    application.register("game-overlay", GameOverlayController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")
  }

  beforeEach(async () => {
    charWidth = 10
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay" data-action="resize@window->game-overlay#fitNames">
        <div style="padding: 0 3px 0 7px" data-game-overlay-target="playerName" data-seat="1">Кот</div>
        <div style="padding: 0 3px 0 7px" data-game-overlay-target="playerName" data-seat="2">Младшенький</div>
        <div style="padding: 0 3px 0 7px" data-game-overlay-target="playerName" data-seat="3">Десятьбукв</div>
        <div style="padding: 0 3px 0 7px" data-game-overlay-target="playerName" data-seat="4">Шестнадцатьбукв!</div>
        <div style="padding: 0 3px 0 7px" data-game-overlay-target="playerName" data-seat="5">Очень длинный никнейм игрока</div>
      </div>
    `
    document.querySelectorAll("[data-game-overlay-target='playerName']").forEach(layOut)
    Range.prototype.getBoundingClientRect = function () {
      return { width: this.startContainer.textContent.length * charWidth * fitOf(this.startContainer) }
    }
    await start()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
    delete document.fonts
    delete Range.prototype.getBoundingClientRect
  })

  it("leaves a name that fits at the base size", () => {
    expect(fit(1)).toBe("")
  })

  it("leaves a name that fills the bar exactly at the base size", () => {
    expect(fit(3)).toBe("")
  })

  it("shrinks a name a fraction of a pixel too wide", () => {
    charWidth = 10.01
    controller.fitNames()

    expect(fit(3)).toBe("0.95")
  })

  it("steps a long name down to the first size that fits", () => {
    expect(fit(2)).toBe("0.9")
  })

  it("shrinks a name that fits only at the minimum to the minimum", () => {
    expect(fit(4)).toBe("0.6")
  })

  it("stops at the minimum when the name does not fit even there", () => {
    expect(fit(5)).toBe("0.6")
  })

  it("connects in a browser without the font loading API", () => {
    expect(controller.subscription).toBeDefined()
  })

  describe("when a name changes live", () => {
    it("ignores a seat with no name bar", () => {
      expect(() => controller.handleUpdate({ scope: "participation", seat: 9, field: "player_name", value: "Кот" })).not.toThrow()
    })

    it("fits the longer name", () => {
      controller.handleUpdate({ scope: "participation", seat: 1, field: "player_name", value: "Младшенький" })

      expect(fit(1)).toBe("0.9")
    })

    it("brings a shorter name back to the base size", () => {
      controller.handleUpdate({ scope: "participation", seat: 2, field: "player_name", value: "Кот" })

      expect(fit(2)).toBe("")
    })

    it("leaves the other names alone", () => {
      nameOf(4).style.removeProperty("--overlay-name-fit")
      controller.handleUpdate({ scope: "participation", seat: 1, field: "player_name", value: "Младшенький" })

      expect(fit(4)).toBe("")
    })
  })

  describe("when the browser source is resized", () => {
    it("fits the names again", () => {
      charWidth = 5
      window.dispatchEvent(new Event("resize"))

      expect([fit(2), fit(4), fit(5)]).toEqual(["", "", "0.7"])
    })
  })

  describe("when the web font finishes loading", () => {
    it("fits the names again once it is ready", async () => {
      application.stop()
      let fontsLoaded
      Object.defineProperty(document, "fonts", { configurable: true, value: { ready: new Promise((resolve) => { fontsLoaded = resolve }) } })
      await start()
      charWidth = 5
      fontsLoaded()
      await document.fonts.ready
      await Promise.resolve()

      expect(fit(2)).toBe("")
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
      <div id="game-overlay" data-controller="game-overlay" data-game-overlay-role-badges-value='{"sheriff":"Ш","don":"Д","mafia":"М"}'>
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
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: "mafia" })

    expect([badge().textContent, badge().dataset.role]).toEqual(["М", "mafia"])
  })

  it("clears the badge when the role changes to civilian", () => {
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: "sheriff" })
    controller.handleUpdate({ scope: "participation", seat: 1, field: "role_code", value: "peace" })

    expect([badge().textContent, badge().dataset.role]).toEqual(["", undefined])
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

describe("GameOverlayController fouls", () => {
  let application
  let controller

  const pips = (seat) => [...document.querySelectorAll(`[data-game-overlay-target="fouls"][data-seat="${seat}"] span`)].map((pip) => pip.className)

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay">
        <div class="overlay-fouls" data-game-overlay-target="fouls" data-seat="3"><span class="overlay-foul"></span></div>
        <div class="overlay-fouls" data-game-overlay-target="fouls" data-seat="4"></div>
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

  it("draws a foul bar per foul, then a tech bar per technical foul", () => {
    controller.handleUpdate({ scope: "fouls", fouls: { 4: { fouls: 2, tech: 1 } } })

    expect(pips(4)).toEqual(["overlay-foul", "overlay-foul", "overlay-tech"])
  })

  it("draws only tech bars for a seat with technical fouls alone", () => {
    controller.handleUpdate({ scope: "fouls", fouls: { 3: { fouls: 0, tech: 2 } } })

    expect(pips(3)).toEqual(["overlay-tech", "overlay-tech"])
  })

  it("clears a seat that is no longer listed", () => {
    controller.handleUpdate({ scope: "fouls", fouls: { 4: { fouls: 1, tech: 0 } } })

    expect(pips(3)).toEqual([])
  })
})

describe("GameOverlayController info block", () => {
  let application
  let controller

  const rows = () => [...document.querySelectorAll(".overlay-info-row")].filter((row) => !row.hidden).map((row) => row.id)
  const text = (id) => document.getElementById(id).textContent
  const send = (field, value) => controller.handleUpdate({ scope: "game", field, value })

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="game-overlay" data-controller="game-overlay" data-game-overlay-game-of-total-template-value="%NUMBER%/%TOTAL%">
        <div id="overlay-info">
          <div id="overlay-table-row" class="overlay-info-row"><span>Стол</span><span id="overlay-table" data-game-overlay-target="table">1</span></div>
          <div id="overlay-game-row" class="overlay-info-row"><span>Игра</span><span id="overlay-game-number" data-game-overlay-target="gameNumber" data-number="3" data-total="">3</span></div>
          <div id="overlay-tournament-row" class="overlay-info-row"><span>Турнир</span><span>Кубок</span></div>
          <div id="overlay-judge-row" class="overlay-info-row" hidden><span>Судья</span><span id="overlay-judge" data-game-overlay-target="judge"></span></div>
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

  describe("when the judge is set", () => {
    beforeEach(() => send("judge", " Петров $& "))

    it("shows the trimmed name as is", () => {
      expect(text("overlay-judge")).toBe("Петров $&")
    })

    it("shows the judge row", () => {
      expect(rows()).toEqual(["overlay-table-row", "overlay-game-row", "overlay-tournament-row", "overlay-judge-row"])
    })
  })

  describe("when the table number changes", () => {
    beforeEach(() => send("table_number", "2"))

    it("shows the new number", () => {
      expect(text("overlay-table")).toBe("2")
    })

    it("keeps the table row", () => {
      expect(rows()).toEqual(["overlay-table-row", "overlay-game-row", "overlay-tournament-row"])
    })
  })

  describe("when the table number is cleared", () => {
    beforeEach(() => send("table_number", "  "))

    it("empties the value", () => {
      expect(text("overlay-table")).toBe("")
    })

    it("leaves the table row out", () => {
      expect(rows()).toEqual(["overlay-game-row", "overlay-tournament-row"])
    })
  })

  describe("when the judge is cleared after being set", () => {
    beforeEach(() => {
      send("judge", "Петров")
      send("judge", null)
    })

    it("leaves the judge row out", () => {
      expect([text("overlay-judge"), rows()]).toEqual(["", ["overlay-table-row", "overlay-game-row", "overlay-tournament-row"]])
    })
  })

  describe("when the total is set", () => {
    beforeEach(() => send("games_total", " 8 "))

    it("shows the game out of the total", () => {
      expect(text("overlay-game-number")).toBe("3/8")
    })

    it("keeps the game number after it changes", () => {
      send("game_number", "4")

      expect(text("overlay-game-number")).toBe("4/8")
    })

    it("shows the number alone once the total is cleared", () => {
      send("games_total", null)

      expect(text("overlay-game-number")).toBe("3")
    })
  })

  describe("when the game and table info are hidden", () => {
    beforeEach(() => {
      send("hide_game_info", "1")
      send("hide_table_info", "1")
    })

    it("marks the canvas so the stylesheet leaves out both rows", () => {
      expect([...document.getElementById("game-overlay").classList]).toEqual(["overlay-canvas--hide-game-info", "overlay-canvas--hide-table-info"])
    })
  })

  describe("when another game field changes", () => {
    beforeEach(() => send("name", "Финал"))

    it("leaves the info block untouched", () => {
      expect([text("overlay-table"), text("overlay-game-number"), text("overlay-judge"), rows()])
        .toEqual(["1", "3", "", ["overlay-table-row", "overlay-game-row", "overlay-tournament-row"]])
    })
  })
})
