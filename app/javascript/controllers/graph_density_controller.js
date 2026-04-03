import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "collapsible"]
  static values = {
    storageKey: { type: String, default: "graph-density" },
    collapsed: { type: Boolean, default: false }
  }

  connect() {
    this.collapsedValue = this.loadPreference()
    this.applyState()
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    this.persistPreference()
    this.applyState()
  }

  applyState() {
    this.collapsibleTargets.forEach((element) => {
      element.hidden = this.collapsedValue
    })

    if (this.hasButtonTarget) {
      this.buttonTarget.classList.toggle("is-active", this.collapsedValue)
      this.buttonTarget.setAttribute("aria-pressed", this.collapsedValue ? "true" : "false")
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.collapsedValue ? "説明を表示" : "説明を省略"
    }

    this.element.classList.toggle("is-compact", this.collapsedValue)
  }

  loadPreference() {
    try {
      return window.localStorage.getItem(this.storageKeyValue) === "collapsed"
    } catch (_error) {
      return this.collapsedValue
    }
  }

  persistPreference() {
    try {
      window.localStorage.setItem(this.storageKeyValue, this.collapsedValue ? "collapsed" : "expanded")
    } catch (_error) {
      // Ignore storage failures and keep the in-memory state.
    }
  }
}
