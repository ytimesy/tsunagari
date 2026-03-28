import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "panel"]
  static values = { activeDepth: Number }

  connect() {
    this.sync()
  }

  activeDepthValueChanged() {
    this.sync()
  }

  switch(event) {
    const requestedDepth = Number(event.currentTarget.dataset.depth)
    if (!requestedDepth || requestedDepth === this.activeDepthValue) return

    this.activeDepthValue = requestedDepth
  }

  sync() {
    if (!this.hasOptionTarget || !this.hasPanelTarget) return

    this.optionTargets.forEach((option) => {
      const active = Number(option.dataset.depth) === this.activeDepthValue

      option.classList.toggle("is-active", active)
      option.setAttribute("aria-pressed", active ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      const active = Number(panel.dataset.depth) === this.activeDepthValue

      panel.hidden = !active
      panel.classList.toggle("is-active", active)
    })
  }
}
