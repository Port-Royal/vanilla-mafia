import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import MenuController from "../../../app/javascript/controllers/menu_controller.js"

const menuMarkup = (name) => `
  <div id="${name}"
       data-controller="menu"
       data-action="click@window->menu#closeOnOutside keydown.esc@window->menu#close">
    <button id="${name}-button" data-menu-target="button" data-action="click->menu#toggle"
            aria-expanded="false" aria-controls="${name}-panel">Menu</button>
    <ul id="${name}-panel" data-menu-target="nav" class="hidden">
      <li><a id="${name}-link" href="#">Link</a></li>
    </ul>
  </div>
`

describe("MenuController", () => {
  let application

  const element = (id) => document.getElementById(id)
  const click = (id) => element(id).click()
  const isOpen = (name) => !element(`${name}-panel`).classList.contains("hidden")
  const expanded = (name) => element(`${name}-button`).getAttribute("aria-expanded")
  const pressKey = (key) => window.dispatchEvent(new KeyboardEvent("keydown", { key }))

  beforeEach(async () => {
    document.body.innerHTML = `
      ${menuMarkup("first")}
      ${menuMarkup("second")}
      <p id="outside">Page</p>
    `

    application = Application.start()
    application.register("menu", MenuController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("toggle", () => {
    it("opens the menu and marks the button expanded", () => {
      click("first-button")

      expect(isOpen("first")).toBe(true)
      expect(expanded("first")).toBe("true")
    })

    it("closes an open menu and marks the button collapsed", () => {
      click("first-button")
      click("first-button")

      expect(isOpen("first")).toBe(false)
      expect(expanded("first")).toBe("false")
    })
  })

  describe("close on Escape", () => {
    it("closes an open menu and marks the button collapsed", () => {
      click("first-button")
      pressKey("Escape")

      expect(isOpen("first")).toBe(false)
      expect(expanded("first")).toBe("false")
    })

    it("ignores other keys", () => {
      click("first-button")
      pressKey("Enter")

      expect(isOpen("first")).toBe(true)
    })
  })

  describe("close on outside click", () => {
    it("closes an open menu when the click lands outside it", () => {
      click("first-button")
      click("outside")

      expect(isOpen("first")).toBe(false)
      expect(expanded("first")).toBe("false")
    })

    it("keeps the menu open when the click lands inside the panel", () => {
      click("first-button")
      click("first-link")

      expect(isOpen("first")).toBe(true)
      expect(expanded("first")).toBe("true")
    })
  })

  describe("two instances on one page", () => {
    it("opens only the toggled menu", () => {
      click("first-button")

      expect(isOpen("first")).toBe(true)
      expect(isOpen("second")).toBe(false)
      expect(expanded("second")).toBe("false")
    })

    it("closes the other menu when the second one is opened", () => {
      click("first-button")
      click("second-button")

      expect(isOpen("first")).toBe(false)
      expect(isOpen("second")).toBe(true)
    })
  })
})
