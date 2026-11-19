import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import MenuController from "../../../app/javascript/controllers/menu_controller.js"

const menuMarkup = (name) => `
  <div id="${name}"
       data-controller="menu"
       data-action="pointerdown@window->menu#closeOnOutside keydown.esc@window->menu#close focusout->menu#closeOnFocusOut turbo:before-cache@document->menu#close">
    <button id="${name}-button" data-menu-target="button" data-action="click->menu#toggle"
            aria-expanded="false" aria-controls="${name}-panel">Menu</button>
    <ul id="${name}-panel" data-menu-target="nav" class="hidden">
      <li><a id="${name}-link" href="#">Link</a></li>
      <li><a id="${name}-other-link" href="#">Other link</a></li>
    </ul>
  </div>
`

describe("MenuController", () => {
  let application

  const element = (id) => document.getElementById(id)
  const click = (id) => element(id).click()
  const press = (id) => {
    pointerDown(id)
    click(id)
  }
  const isOpen = (name) => !element(`${name}-panel`).classList.contains("hidden")
  const expanded = (name) => element(`${name}-button`).getAttribute("aria-expanded")
  const pressKey = (key) => window.dispatchEvent(new KeyboardEvent("keydown", { key }))
  const pointerDown = (id) => element(id).dispatchEvent(new Event("pointerdown", { bubbles: true }))
  const focusOut = (id, relatedTarget) =>
    element(id).dispatchEvent(new FocusEvent("focusout", { bubbles: true, relatedTarget }))

  beforeEach(async () => {
    document.body.innerHTML = `
      ${menuMarkup("first")}
      ${menuMarkup("second")}
      <p id="outside">Page</p>
      <a id="outside-link" href="#">Elsewhere</a>
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

    it("returns focus to the button when focus was inside the panel", () => {
      click("first-button")
      element("first-link").focus()
      pressKey("Escape")

      expect(document.activeElement).toBe(element("first-button"))
    })

    it("leaves focus alone when it was outside the panel", () => {
      click("first-button")
      element("outside-link").focus()
      pressKey("Escape")

      expect(document.activeElement).toBe(element("outside-link"))
    })

    it("ignores other keys", () => {
      click("first-button")
      pressKey("Enter")

      expect(isOpen("first")).toBe(true)
    })
  })

  describe("close on outside pointerdown", () => {
    it("closes an open menu when the pointer goes down outside it", () => {
      click("first-button")
      pointerDown("outside")

      expect(isOpen("first")).toBe(false)
      expect(expanded("first")).toBe("false")
    })

    it("keeps the menu open when the pointer goes down inside the panel", () => {
      click("first-button")
      pointerDown("first-link")

      expect(isOpen("first")).toBe(true)
      expect(expanded("first")).toBe("true")
    })
  })

  describe("close on focus leaving the menu", () => {
    it("closes an open menu when focus moves outside it", () => {
      click("first-button")
      focusOut("first-link", element("outside"))

      expect(isOpen("first")).toBe(false)
      expect(expanded("first")).toBe("false")
    })

    it("keeps the menu open when focus moves within it", () => {
      click("first-button")
      focusOut("first-link", element("first-other-link"))

      expect(isOpen("first")).toBe(true)
    })

    it("keeps the menu open when focus goes nowhere", () => {
      click("first-button")
      focusOut("first-link", null)

      expect(isOpen("first")).toBe(true)
    })
  })

  describe("close before Turbo caches the page", () => {
    it("closes an open menu", () => {
      click("first-button")
      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(isOpen("first")).toBe(false)
      expect(expanded("first")).toBe("false")
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
      press("first-button")
      press("second-button")

      expect(isOpen("first")).toBe(false)
      expect(isOpen("second")).toBe(true)
    })
  })
})
