import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["canvas", "filter", "reset"]
  static values = { graph: Object, palette: Object }

  connect() {
    this.activeKinds = new Set(this.availableKinds())
    this.boundClick = this.handleClick.bind(this)
    this.boundKeydown = this.handleKeydown.bind(this)
    this.canvasTarget.addEventListener("click", this.boundClick)
    this.canvasTarget.addEventListener("keydown", this.boundKeydown)
    this.render()
    this.syncInterface()
  }

  disconnect() {
    this.canvasTarget.removeEventListener("click", this.boundClick)
    this.canvasTarget.removeEventListener("keydown", this.boundKeydown)
  }

  graphValueChanged() {
    this.activeKinds = new Set(this.availableKinds())
    this.render()
    this.syncInterface()
  }

  toggleKind(event) {
    const kind = event.currentTarget.dataset.kind
    if (!kind) return

    if (this.activeKinds.has(kind)) {
      this.activeKinds.delete(kind)
    } else {
      this.activeKinds.add(kind)
    }

    this.render()
    this.syncInterface()
  }

  showAllKinds() {
    this.activeKinds = new Set(this.availableKinds())
    this.render()
    this.syncInterface()
  }

  render() {
    const graph = this.graphValue
    const visibleEdges = this.visibleEdges(graph)
    const showAllLabels = this.showAllLabels(graph)
    const hasAnyEdges = !!(graph && graph.edges && graph.edges.length > 0)

    if (!graph || !graph.nodes || graph.nodes.length === 0) {
      this.canvasTarget.innerHTML = "<p class=\"empty-note\">図にできる関係はまだありません。</p>"
      return
    }

    if (hasAnyEdges && visibleEdges.length === 0) {
      this.canvasTarget.innerHTML = "<p class=\"empty-note\">選択中の関係タイプでは図にできる線がありません。</p>"
      return
    }

    const visibleNodes = hasAnyEdges ? this.visibleNodes(graph, visibleEdges) : graph.nodes
    const degreeByNodeId = this.degreeByNodeId(visibleNodes, visibleEdges)
    const { width, height } = this.dimensionsFor(visibleNodes.length)
    const positions = this.buildPositions(visibleNodes, graph.centerId, width, height)

    const edgeMarkup = visibleEdges.map((edge) => {
      const from = positions.get(edge.source)
      const to = positions.get(edge.target)
      const stroke = this.edgeStroke(edge)
      const strokeWidth = Math.max(1.8, Math.min(4.8, 1.2 + ((edge.weight || 1) * 0.45)))
      const relationLabel = edge.kindLabel ? `${edge.kindLabel} / ` : ""

      return `
        <line x1="${from.x}" y1="${from.y}" x2="${to.x}" y2="${to.y}" stroke="${stroke}" stroke-width="${strokeWidth}" stroke-linecap="round" opacity="0.82">
          <title>${this.escape(edge.sourceLabel)} × ${this.escape(edge.targetLabel)}: ${this.escape(relationLabel + edge.reason)}</title>
        </line>
      `
    }).join("")

    const nodeMarkup = visibleNodes.map((node) => {
      const nodeDegree = node.degree ?? degreeByNodeId.get(node.id) ?? 0
      const displayNode = { ...node, degree: nodeDegree }
      const point = positions.get(node.id)
      const radius = this.nodeRadius(displayNode, visibleNodes.length)
      const fill = this.nodeFill(displayNode)
      const stroke = this.nodeStroke(displayNode)
      const textFill = displayNode.role === "focus" ? "#ffffff" : "#324132"
      const renderInnerLabel = this.shouldShowInnerLabel(displayNode, visibleNodes.length, showAllLabels)
      const renderOuterLabel = this.shouldShowOuterLabel(displayNode, visibleNodes.length, showAllLabels, renderInnerLabel)
      const innerLabel = renderInnerLabel ? this.escape(this.compactLabel(displayNode.label, displayNode.role === "focus" ? 10 : 8)) : ""
      const outerLabel = renderOuterLabel ? `<text y="${radius + 18}" text-anchor="middle" font-size="12" font-weight="700" fill="#324132">${this.escape(this.compactLabel(displayNode.label, 18))}</text>` : ""

      return `
        <g
          transform="translate(${point.x}, ${point.y})"
          class="relationship-node"
          data-node-href="${this.escape(node.href)}"
          data-node-label="${this.escape(node.label)}"
          tabindex="0"
          role="link"
          aria-label="${this.escape(`${node.label} の人物詳細を開く`)}">
            <circle r="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="${node.role === "isolated" ? 2 : 3}"></circle>
            <title>${this.escape(node.label)}</title>
            ${innerLabel ? `<text y="4" text-anchor="middle" font-size="11" font-weight="700" fill="${textFill}">${innerLabel}</text>` : ""}
            ${outerLabel}
        </g>
      `
    }).join("")

    this.canvasTarget.innerHTML = `
      <svg class="relationship-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="人と人との関連図">
        <rect width="${width}" height="${height}" rx="28" fill="rgba(255,255,255,0.6)"></rect>
        ${edgeMarkup}
        ${nodeMarkup}
      </svg>
    `
  }

  visibleEdges(graph) {
    if (!graph?.edges) return []

    return graph.edges.filter((edge) => this.activeKinds.has(edge.kind || "same_field"))
  }

  visibleNodes(graph, visibleEdges) {
    const visibleNodeIds = new Set()

    visibleEdges.forEach((edge) => {
      visibleNodeIds.add(edge.source)
      visibleNodeIds.add(edge.target)
    })

    if (graph.centerId) {
      visibleNodeIds.add(graph.centerId)
    }

    return graph.nodes.filter((node) => visibleNodeIds.has(node.id))
  }

  degreeByNodeId(visibleNodes, visibleEdges) {
    const counts = new Map(visibleNodes.map((node) => [node.id, 0]))

    visibleEdges.forEach((edge) => {
      counts.set(edge.source, (counts.get(edge.source) || 0) + 1)
      counts.set(edge.target, (counts.get(edge.target) || 0) + 1)
    })

    return counts
  }

  syncInterface() {
    this.syncFilterState()
  }

  syncFilterState() {
    const availableKinds = this.availableKinds()
    const allSelected = availableKinds.length > 0 && availableKinds.every((kind) => this.activeKinds.has(kind))

    if (this.hasResetTarget) {
      this.resetTarget.classList.toggle("is-active", allSelected)
      this.resetTarget.classList.toggle("is-inactive", !allSelected)
      this.resetTarget.setAttribute("aria-pressed", allSelected ? "true" : "false")
    }

    this.filterTargets.forEach((button) => {
      const active = this.activeKinds.has(button.dataset.kind)

      button.classList.toggle("is-active", active)
      button.classList.toggle("is-inactive", !active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  availableKinds() {
    return [...new Set((this.graphValue?.edges || []).map((edge) => edge.kind || "same_field"))]
  }

  edgeStroke(edge) {
    const palette = this.paletteValue?.[edge.kind]
    if (palette?.stroke) return palette.stroke

    return edge.tone === "similar" ? "#4b84b6" : "#cda43d"
  }

  dimensionsFor(nodeCount) {
    if (nodeCount > 200) return { width: 1520, height: 1120 }
    if (nodeCount > 120) return { width: 1320, height: 960 }
    if (nodeCount > 60) return { width: 1120, height: 820 }
    return { width: 760, height: 380 }
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

    const ringSizes = this.ringSizesFor(outerNodes.length, centerId)
    const maxRadius = Math.max(72, (Math.min(width, height) / 2) - 46)
    const firstRadius = ringSizes.length > 1 ? Math.max(54, maxRadius * 0.42) : Math.max(48, maxRadius * 0.58)
    const radiusStep = ringSizes.length > 1 ? (maxRadius - firstRadius) / (ringSizes.length - 1) : 0
    let cursor = 0

    ringSizes.forEach((ringSize, ringIndex) => {
      const ringRadius = firstRadius + (radiusStep * ringIndex)
      const ringNodes = outerNodes.slice(cursor, cursor + ringSize)

      ringNodes.forEach((node, index) => {
        const angle = (-Math.PI / 2) + ((Math.PI * 2 * index) / ringNodes.length)
        positions.set(node.id, {
          x: centerX + Math.cos(angle) * ringRadius,
          y: centerY + Math.sin(angle) * ringRadius
        })
      })

      cursor += ringSize
    })

    return positions
  }

  ringSizesFor(nodeCount, centerId) {
    if (nodeCount <= 0) return []

    const ringSizes = []
    let remaining = nodeCount
    let ringIndex = 0

    while (remaining > 0) {
      const ringSize = Math.min(this.ringCapacity(ringIndex, nodeCount, centerId), remaining)
      ringSizes.push(ringSize)
      remaining -= ringSize
      ringIndex += 1
    }

    return ringSizes
  }

  ringCapacity(ringIndex, nodeCount, centerId) {
    if (nodeCount <= 12) return nodeCount

    const base = centerId ? 10 : 14
    return base + (ringIndex * 10)
  }

  nodeRadius(node, nodeCount) {
    if (node.role === "focus") return nodeCount > 80 ? 18 : 26
    if (nodeCount > 180) return node.degree >= 3 ? 8 : 6
    if (nodeCount > 80) return node.degree >= 3 ? 10 : 8
    if (nodeCount > 40) return 12
    return 20
  }

  nodeFill(node) {
    if (node.role === "focus") return "#355c4a"
    if (node.role === "isolated") return "rgba(255, 255, 255, 0.55)"
    return "#fdfcf7"
  }

  nodeStroke(node) {
    if (node.role === "focus") return "#355c4a"
    if (node.role === "isolated") return "rgba(133, 146, 126, 0.48)"
    return "#8aa07d"
  }

  shouldShowInnerLabel(node, nodeCount, showAllLabels = false) {
    if (showAllLabels && node.role !== "focus") return false
    if (node.role === "focus") return true
    if (nodeCount <= 28) return true
    if (nodeCount <= 80) return node.degree >= 2
    return false
  }

  shouldShowOuterLabel(node, nodeCount, showAllLabels = false, innerLabelVisible = false) {
    if (showAllLabels) return node.role !== "focus" && !innerLabelVisible
    if (node.role === "focus") return true
    if (nodeCount <= 18) return true
    if (nodeCount <= 60) return node.degree >= 2
    return node.degree >= 3
  }

  showAllLabels(graph) {
    return graph?.labelMode === "all"
  }

  compactLabel(label, maxLength) {
    if (label.length <= maxLength) return label

    return `${label.slice(0, maxLength - 1)}…`
  }

  handleClick(event) {
    const node = this.nodeForEvent(event)
    if (!node) return

    this.visit(node.dataset.nodeHref)
  }

  handleKeydown(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    const node = this.nodeForEvent(event)
    if (!node) return

    event.preventDefault()
    this.visit(node.dataset.nodeHref)
  }

  visit(url) {
    if (!url) return

    Turbo.visit(url)
  }

  nodeForEvent(event) {
    if (typeof event.composedPath === "function") {
      const matchingNode = event.composedPath().find((element) => element?.dataset?.nodeHref)
      if (matchingNode) return matchingNode
    }

    let current = event.target
    while (current) {
      if (current.dataset?.nodeHref) return current
      current = current.parentNode
    }

    return null
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
