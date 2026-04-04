import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.refresh()
  }

  append(event) {
    if (!this.hasInputTarget) return

    const tagName = event.currentTarget.dataset.tagName?.trim()
    if (!tagName) return

    const tags = this.normalizedTags()
    const existing = new Set(tags.map((tag) => tag.toLowerCase()))

    if (!existing.has(tagName.toLowerCase())) {
      tags.push(tagName)
      this.inputTarget.value = tags.join(", ")
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    this.refresh()
    this.inputTarget.focus()
  }

  refresh() {
    const selected = new Set(this.normalizedTags().map((tag) => tag.toLowerCase()))

    this.buttonTargets.forEach((button) => {
      const tagName = button.dataset.tagName?.trim().toLowerCase()
      const active = tagName && selected.has(tagName)
      button.classList.toggle("is-selected", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  normalizedTags() {
    return this.inputTarget.value
      .split(",")
      .map((value) => value.trim())
      .filter((value) => value.length > 0)
  }
}
