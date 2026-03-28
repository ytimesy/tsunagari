import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { graph: Object }

  connect() {
    this.render()
  }

  graphValueChanged() {
    this.render()
  }

  render() {
    const graph = this.graphValue

    if (!graph || !graph.nodes || graph.nodes.length === 0 || !graph.edges || graph.edges.length === 0) {
      this.element.innerHTML = "<p class=\"empty-note\">図にできる関係はまだありません。</p>"
      return
    }

    const width = 760
    const height = 380
    const positions = this.buildPositions(graph.nodes, graph.centerId, width, height)
    const nodeMap = new Map(graph.nodes.map((node) => [node.id, node]))

    const edgeMarkup = graph.edges.map((edge) => {
      const from = positions.get(edge.source)
      const to = positions.get(edge.target)
      const stroke = edge.tone === "similar" ? "#4b84b6" : "#cda43d"

      return `
        <line x1="${from.x}" y1="${from.y}" x2="${to.x}" y2="${to.y}" stroke="${stroke}" stroke-width="4" stroke-linecap="round" opacity="0.9">
          <title>${this.escape(edge.sourceLabel)} × ${this.escape(edge.targetLabel)}: ${this.escape(edge.reason)}</title>
        </line>
      `
    }).join("")

    const nodeMarkup = graph.nodes.map((node) => {
      const point = positions.get(node.id)
      const radius = node.role === "focus" ? 26 : 20
      const fill = node.role === "focus" ? "#355c4a" : "#fdfcf7"
      const stroke = node.role === "focus" ? "#355c4a" : "#8aa07d"
      const textFill = node.role === "focus" ? "#ffffff" : "#324132"

      return `
        <g transform="translate(${point.x}, ${point.y})">
          <a href="${node.href}" class="relationship-node-link">
            <circle r="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="3"></circle>
            <text y="4" text-anchor="middle" font-size="11" font-weight="700" fill="${textFill}">${this.escape(this.compactLabel(node.label, node.role === "focus" ? 10 : 9))}</text>
          </a>
          <text y="${radius + 22}" text-anchor="middle" font-size="12" font-weight="700" fill="#324132">${this.escape(this.compactLabel(node.label, 18))}</text>
        </g>
      `
    }).join("")

    this.element.innerHTML = `
      <svg class="relationship-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="人と人との関連図">
        <rect width="${width}" height="${height}" rx="28" fill="rgba(255,255,255,0.6)"></rect>
        ${edgeMarkup}
        ${nodeMarkup}
      </svg>
    `
  }

  buildPositions(nodes, centerId, width, height) {
    const positions = new Map()
    const centerX = width / 2
    const centerY = height / 2
    const outerNodes = centerId ? nodes.filter((node) => node.id !== centerId) : nodes

    if (centerId) {
      positions.set(centerId, { x: centerX, y: centerY })
    }

    if (outerNodes.length === 0) {
      return positions
    }

    if (!centerId && outerNodes.length === 1) {
      positions.set(outerNodes[0].id, { x: centerX, y: centerY })
      return positions
    }

    const radius = Math.min(width, height) * (centerId ? 0.34 : 0.36)
    outerNodes.forEach((node, index) => {
      const angle = (-Math.PI / 2) + ((Math.PI * 2 * index) / outerNodes.length)
      positions.set(node.id, {
        x: centerX + Math.cos(angle) * radius,
        y: centerY + Math.sin(angle) * radius
      })
    })

    return positions
  }

  compactLabel(label, maxLength) {
    if (label.length <= maxLength) return label

    return `${label.slice(0, maxLength - 1)}…`
  }

  escape(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;")
      .replaceAll("'", "&#39;")
  }
}
