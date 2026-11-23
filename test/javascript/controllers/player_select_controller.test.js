import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import PlayerSelectController from "../../../app/javascript/controllers/player_select_controller.js"

describe("PlayerSelectController", () => {
  let application
  let scrollIntoView

  const html = `
    <template id="player-options">
      <button type="button" class="w-full" data-player-select-target="option" data-player-name="Anna"
              data-action="mouseenter->player-select#hover">Anna</button>
      <button type="button" class="w-full" data-player-select-target="option" data-player-name="Boris"
              data-action="mouseenter->player-select#hover">Boris</button>
      <button type="button" class="w-full" data-player-select-target="option" data-player-name="Vera"
              data-action="mouseenter->player-select#hover">Vera</button>
    </template>
    <div data-controller="player-select">
      <input data-player-select-target="search"
             data-action="focus->player-select#open input->player-select#filter keydown->player-select#onKeydown">
      <div data-player-select-target="menu" class="hidden"></div>
    </div>
  `

  const search = () => document.querySelector("input")
  const options = () => Array.from(document.querySelectorAll("[data-player-select-target='menu'] button"))
  const washed = () => options().filter((option) => option.classList.contains("bg-gold-wash")).map((option) => option.textContent)
  const visible = () => options().filter((option) => !option.classList.contains("hidden")).map((option) => option.textContent)
  const type = async (value) => {
    search().value = value
    search().dispatchEvent(new Event("input", { bubbles: true }))
    await Promise.resolve()
  }
  const press = async (key) => {
    search().dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true }))
    await Promise.resolve()
  }

  beforeEach(async () => {
    scrollIntoView = vi.fn()
    Element.prototype.scrollIntoView = scrollIntoView
    document.body.innerHTML = html
    application = Application.start()
    application.register("player-select", PlayerSelectController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("when the arrow key opens the menu", () => {
    beforeEach(async () => press("ArrowDown"))

    it("washes the first option gold", () => {
      expect(washed()).toEqual(["Anna"])
    })

    it("scrolls the washed option into view", () => {
      expect(scrollIntoView).toHaveBeenCalledWith({ block: "nearest" })
    })
  })

  describe("when the arrow key moves on", () => {
    beforeEach(async () => {
      await press("ArrowDown")
      await press("ArrowDown")
    })

    it("moves the wash to the next option", () => {
      expect(washed()).toEqual(["Boris"])
    })
  })

  describe("when the mouse hovers an option", () => {
    beforeEach(async () => {
      await press("ArrowDown")
      options()[1].dispatchEvent(new MouseEvent("mouseenter"))
      await Promise.resolve()
    })

    it("moves the wash to the hovered option", () => {
      expect(washed()).toEqual(["Boris"])
    })
  })

  describe("when the query changes", () => {
    beforeEach(async () => {
      await press("ArrowDown")
      await type("")
    })

    it("clears the wash", () => {
      expect(washed()).toEqual([])
    })
  })

  describe("when the arrow key follows a query change", () => {
    beforeEach(async () => {
      await press("ArrowDown")
      await type("")
      await press("ArrowDown")
    })

    it("starts the wash from the first option again", () => {
      expect(washed()).toEqual(["Anna"])
    })
  })

  describe("when the query is typed in another case with spaces", () => {
    beforeEach(async () => {
      await press("ArrowDown")
      await type("  ANN ")
    })

    it("shows only the matching option", () => {
      expect(visible()).toEqual(["Anna"])
    })
  })
})
