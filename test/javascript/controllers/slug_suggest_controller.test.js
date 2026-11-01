import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import SlugSuggestController from "../../../app/javascript/controllers/slug_suggest_controller.js"

describe("SlugSuggestController", () => {
  let application
  let source
  let slug

  const type = (value) => {
    source.value = value
    source.dispatchEvent(new Event("input"))
  }

  beforeEach(async () => {
    document.body.innerHTML = `
      <input id="source"
             data-controller="slug-suggest"
             data-slug-suggest-target-value="slug"
             data-action="input->slug-suggest#suggest">
      <input id="slug">
    `
    source = document.getElementById("source")
    slug = document.getElementById("slug")

    application = Application.start()
    application.register("slug-suggest", SlugSuggestController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  it("lowercases the text and joins words with a dash", () => {
    type("Hello World")

    expect(slug.value).toBe("hello-world")
  })

  it("keeps Cyrillic letters and digits", () => {
    type("Сезон 8")

    expect(slug.value).toBe("сезон-8")
  })

  it("collapses a run of separators into one dash", () => {
    type("one, - two")

    expect(slug.value).toBe("one-two")
  })

  it("removes every leading and trailing dash", () => {
    type("  !!one!!  ")

    expect(slug.value).toBe("one")
  })

  it("leaves a slug the user edited by hand", () => {
    slug.value = "custom"
    slug.dataset.slugEdited = "true"

    type("Hello")

    expect(slug.value).toBe("custom")
  })

  it("overwrites the slug when the edited flag is not true", () => {
    slug.value = "custom"
    slug.dataset.slugEdited = "false"

    type("Hello")

    expect(slug.value).toBe("hello")
  })

  it("does nothing when the slug input is missing", () => {
    slug.remove()

    expect(() => type("Hello")).not.toThrow()
  })
})
