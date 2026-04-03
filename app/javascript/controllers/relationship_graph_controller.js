import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["canvas", "filter", "reset", "inspectorEyebrow", "inspectorTitle", "inspectorMeta", "inspectorBody"]
  static values = {
    graph: Object,
    palette: Object,
    clusterPalette: Object,
    inspectorTitle: String,
    inspectorMeta: String,
    inspectorBody: String
  }

  connect() {
    this.activeKinds = new Set(this.availableKinds())
    this.boundClick = this.handleClick.bind(this)
    this.boundKeydown = this.handleKeydown.bind(this)
    this.boundMouseover = this.handleMouseover.bind(this)
    this.boundMouseout = this.handleMouseout.bind(this)
    this.boundFocusin = this.handleFocusin.bind(this)
    this.boundFocusout = this.handleFocusout.bind(this)

    this.canvasTarget.addEventListener("click", this.boundClick)
    this.canvasTarget.addEventListener("keydown", this.boundKeydown)
    this.canvasTarget.addEventListener("mouseover", this.boundMouseover)
    this.canvasTarget.addEventListener("mouseout", this.boundMouseout)
    this.canvasTarget.addEventListener("focusin", this.boundFocusin)
    this.canvasTarget.addEventListener("focusout", this.boundFocusout)

    this.render()
    this.syncInterface()
    this.resetInspector()
  }

  disconnect() {
    this.canvasTarget.removeEventListener("click", this.boundClick)
    this.canvasTarget.removeEventListener("keydown", this.boundKeydown)
    this.canvasTarget.removeEventListener("mouseover", this.boundMouseover)
    this.canvasTarget.removeEventListener("mouseout", this.boundMouseout)
    this.canvasTarget.removeEventListener("focusin", this.boundFocusin)
    this.canvasTarget.removeEventListener("focusout", this.boundFocusout)
  }

  graphValueChanged() {
    this.activeKinds = new Set(this.availableKinds())
    this.render()
    this.syncInterface()
    this.resetInspector()
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
    this.resetInspector()
  }

  showAllKinds() {
    this.activeKinds = new Set(this.availableKinds())
    this.render()
    this.syncInterface()
    this.resetInspector()
  }

  render() {
    const graph = this.graphValue
    const visibleEdges = this.visibleEdges(graph)
    const showAllLabels = this.showAllLabels(graph)
    const hasAnyEdges = !!(graph && graph.edges && graph.edges.length > 0)

    if (!graph || !graph.nodes || graph.nodes.length === 0) {
      this.canvasTarget.innerHTML = '<p class="empty-note">図にできる関係はまだありません。</p>'
      return
    }

    if (hasAnyEdges && visibleEdges.length === 0) {
      this.canvasTarget.innerHTML = '<p class="empty-note">選択中の関係タイプでは図にできる線がありません。</p>'
      return
    }

    const visibleNodes = hasAnyEdges ? this.visibleNodes(graph, visibleEdges) : graph.nodes
    const degreeByNodeId = this.degreeByNodeId(visibleNodes, visibleEdges)
    const { width, height } = this.dimensionsFor(visibleNodes.length, graph)
    const positions = this.buildPositions(visibleNodes, graph.centerId, width, height)

    const edgeMarkup = visibleEdges.filter((edge) => positions.has(edge.source) && positions.has(edge.target)).map((edge) => {
      const from = positions.get(edge.source)
      const to = positions.get(edge.target)
      const stroke = this.edgeStroke(edge, graph)
      const strokeWidth = this.edgeStrokeWidth(edge, graph)
      const emphasis = this.edgeEmphasis(edge, graph)
      const inspector = this.edgeInspector(edge, graph)
      const title = `${edge.sourceLabel} × ${edge.targetLabel}: ${edge.reason || edge.kindDescription || "関係があります"}`

      return `
        <g class="relationship-edge-group${emphasis.isMuted ? " is-muted" : ""}">
          <line x1="${from.x}" y1="${from.y}" x2="${to.x}" y2="${to.y}" stroke="${stroke}" stroke-width="${strokeWidth}" stroke-linecap="round" opacity="${emphasis.opacity}" pointer-events="none"></line>
          <line
            class="relationship-edge-hit"
            x1="${from.x}" y1="${from.y}" x2="${to.x}" y2="${to.y}"
            stroke="rgba(255,255,255,0.001)"
            stroke-width="${Math.max(strokeWidth + 12, 16)}"
            stroke-linecap="round"
            tabindex="0"
            focusable="true"
            role="img"
            aria-label="${this.escape(inspector.accessibleLabel)}"
            data-inspector-eyebrow="${this.escape(inspector.eyebrow)}"
            data-inspector-title="${this.escape(inspector.title)}"
            data-inspector-meta="${this.escape(inspector.meta)}"
            data-inspector-body="${this.escape(inspector.body)}">
            <title>${this.escape(title)}</title>
          </line>
        </g>
      `
    }).join("")

    const nodeMarkup = visibleNodes.map((node) => {
      const nodeDegree = node.degree ?? degreeByNodeId.get(node.id) ?? 0
      const displayNode = { ...node, degree: nodeDegree }
      const point = positions.get(node.id)
      const radius = this.nodeRadius(displayNode, visibleNodes.length, graph)
      const fill = this.nodeFill(displayNode, graph)
      const stroke = this.nodeStroke(displayNode, graph)
      const textFill = this.nodeTextFill(displayNode, graph)
      const outerLabelFill = this.outerLabelFill(displayNode, graph)
      const renderInnerLabel = this.shouldShowInnerLabel(displayNode, visibleNodes.length, showAllLabels)
      const renderOuterLabel = this.shouldShowOuterLabel(displayNode, visibleNodes.length, showAllLabels, renderInnerLabel)
      const innerLabel = renderInnerLabel ? this.escape(this.compactLabel(displayNode.label, displayNode.role === "focus" ? 12 : 8)) : ""
      const outerLabel = renderOuterLabel ? `<text y="${radius + 18}" text-anchor="middle" font-size="12" font-weight="700" fill="${outerLabelFill}">${this.escape(this.compactLabel(displayNode.label, 24))}</text>` : ""
      const inspector = this.nodeInspector(displayNode, graph)
      const halo = displayNode.role === "focus" && graph?.variant === "cluster_overview"
        ? `<circle r="${radius + 10}" fill="${this.clusterPalette(displayNode.category).halo}" stroke="none"></circle>`
        : ""

      return `
        <g
          transform="translate(${point.x}, ${point.y})"
          class="relationship-node${displayNode.role === "focus" ? " is-selected" : ""}${graph?.variant === "cluster_overview" ? " is-cluster" : ""}"
          data-node-href="${this.escape(node.href)}"
          data-node-label="${this.escape(node.label)}"
          data-inspector-eyebrow="${this.escape(inspector.eyebrow)}"
          data-inspector-title="${this.escape(inspector.title)}"
          data-inspector-meta="${this.escape(inspector.meta)}"
          data-inspector-body="${this.escape(inspector.body)}"
          tabindex="0"
          role="link"
          aria-label="${this.escape(inspector.accessibleLabel)}">
            ${halo}
            <circle r="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="${displayNode.role === "isolated" ? 2 : 3}"></circle>
            <title>${this.escape(node.label)}</title>
            ${innerLabel ? `<text y="4" text-anchor="middle" font-size="11" font-weight="700" fill="${textFill}">${innerLabel}</text>` : ""}
            ${outerLabel}
        </g>
      `
    }).join("")

    this.canvasTarget.innerHTML = `
      <svg class="relationship-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="${this.escape(graph.ariaLabel || "関係図")}">
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

  edgeStroke(edge, graph) {
    if (graph?.variant === "cluster_overview") {
      return edge.tone === "diverse" ? "#d38a45" : "#628abf"
    }

    const palette = this.paletteValue?.[edge.kind]
    if (palette?.stroke) return palette.stroke

    return edge.tone === "similar" ? "#4b84b6" : "#cda43d"
  }

  edgeStrokeWidth(edge, graph) {
    if (graph?.variant === "cluster_overview") {
      const scaled = 1.8 + (Math.sqrt(edge.weight || 1) * 1.25)
      return Math.max(2.2, Math.min(7.2, scaled))
    }

    return Math.max(1.8, Math.min(4.8, 1.2 + ((edge.weight || 1) * 0.45)))
  }

  edgeEmphasis(edge, graph) {
    if (graph?.variant === "cluster_overview" && graph.centerId) {
      const isConnectedToSelection = edge.source === graph.centerId || edge.target === graph.centerId
      return { opacity: isConnectedToSelection ? 0.96 : 0.3, isMuted: !isConnectedToSelection }
    }

    return { opacity: graph?.variant === "cluster_overview" ? 0.86 : 0.82, isMuted: false }
  }

  dimensionsFor(nodeCount, graph) {
    if (graph?.variant === "cluster_overview") {
      if (nodeCount > 16) return { width: 1040, height: 620 }
      if (nodeCount > 8) return { width: 940, height: 560 }
      return { width: 860, height: 500 }
    }

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
    const maxRadius = Math.max(72, (Math.min(width, height) / 2) - 56)
    const firstRadius = ringSizes.length > 1 ? Math.max(66, maxRadius * 0.4) : Math.max(54, maxRadius * 0.58)
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

  nodeRadius(node, nodeCount, graph) {
    if (node.population) {
      const scaled = Math.sqrt(node.population)
      const base = node.role === "focus" ? 20 : 15
      const radius = base + (scaled * 2)
      return Math.max(base, Math.min(node.role === "focus" ? 44 : 34, radius))
    }

    if (node.role === "focus") return nodeCount > 80 ? 18 : 26
    if (nodeCount > 180) return node.degree >= 3 ? 8 : 6
    if (nodeCount > 80) return node.degree >= 3 ? 10 : 8
    if (nodeCount > 40) return 12
    return graph?.variant === "cluster_overview" ? 18 : 20
  }

  nodeFill(node, graph) {
    if (graph?.variant === "cluster_overview") {
      const palette = this.clusterPalette(node.category)
      if (node.role === "focus") return palette.accent
      if (node.role === "isolated") return "rgba(255, 255, 255, 0.7)"
      return palette.fill
    }

    if (node.role === "focus") return "#355c4a"
    if (node.role === "isolated") return "rgba(255, 255, 255, 0.55)"
    return "#fdfcf7"
  }

  nodeStroke(node, graph) {
    if (graph?.variant === "cluster_overview") {
      const palette = this.clusterPalette(node.category)
      if (node.role === "focus") return palette.accent
      if (node.role === "isolated") return "rgba(133, 146, 126, 0.42)"
      return palette.accent
    }

    if (node.role === "focus") return "#355c4a"
    if (node.role === "isolated") return "rgba(133, 146, 126, 0.48)"
    return "#8aa07d"
  }

  nodeTextFill(node, graph) {
    if (graph?.variant === "cluster_overview") {
      if (node.role === "focus") return "#ffffff"
      return this.clusterPalette(node.category).text
    }

    return node.role === "focus" ? "#ffffff" : "#324132"
  }

  outerLabelFill(node, graph) {
    if (graph?.variant === "cluster_overview") {
      return this.clusterPalette(node.category).text
    }

    return "#324132"
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
    if (String(label).length <= maxLength) return label

    return `${String(label).slice(0, maxLength - 1)}…`
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

  handleMouseover(event) {
    const element = this.inspectorElementForEvent(event)
    if (!element) return

    this.updateInspectorFrom(element)
  }

  handleMouseout(event) {
    const next = this.inspectorElementFromNode(event.relatedTarget)
    if (next) return

    this.resetInspector()
  }

  handleFocusin(event) {
    const element = this.inspectorElementForEvent(event)
    if (!element) return

    this.updateInspectorFrom(element)
  }

  handleFocusout(event) {
    const next = this.inspectorElementFromNode(event.relatedTarget)
    if (next) return

    this.resetInspector()
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

  edgeInspector(edge, graph) {
    if (graph?.variant === "cluster_overview") {
      const meta = [
        `接点 ${edge.pairCount || edge.weight || 0} 件`,
        edge.kindLabel ? `主な関係 ${edge.kindLabel}` : null,
        edge.toneLabel
      ].filter(Boolean).join(" / ")
      const details = []
      if (edge.sharedOrganizations?.length) details.push(`代表所属: ${edge.sharedOrganizations.join(" / ")}`)
      if (edge.sharedTags?.length) details.push(`代表タグ: ${edge.sharedTags.join(" / ")}`)
      if (!details.length && edge.reason) details.push(edge.reason)

      return {
        eyebrow: "接点",
        title: `${edge.sourceLabel} × ${edge.targetLabel}`,
        meta,
        body: details.join("  "),
        accessibleLabel: `${edge.sourceLabel} と ${edge.targetLabel}。${meta}。${details.join("。")}`
      }
    }

    const meta = [edge.kindLabel, edge.tone === "diverse" ? "越境的な関係" : "近い文脈の関係"].filter(Boolean).join(" / ")
    const body = edge.reason || edge.kindDescription || "関係の説明はまだありません。"

    return {
      eyebrow: "関係",
      title: `${edge.sourceLabel} × ${edge.targetLabel}`,
      meta,
      body,
      accessibleLabel: `${edge.sourceLabel} と ${edge.targetLabel}。${meta}。${body}`
    }
  }

  nodeInspector(node, graph) {
    if (graph?.variant === "cluster_overview") {
      const meta = [
        node.categoryLabel || "クラスタ",
        node.population ? `${node.population} 人` : null,
        node.degree > 0 ? `接点 ${node.degree}` : "接点は少なめ"
      ].filter(Boolean).join(" / ")
      const body = node.role === "focus"
        ? "このクラスタを下段で詳しく表示しています。別のクラスタを選ぶと、下段の詳細が切り替わります。"
        : "選ぶと、この画面の下段に人物関係と構成情報が開きます。"

      return {
        eyebrow: node.categoryLabel || "クラスタ",
        title: node.label,
        meta,
        body,
        accessibleLabel: `${node.label}。${meta}。${body}`
      }
    }

    const meta = [node.role === "focus" ? "中心人物" : "人物", node.degree > 0 ? `接点 ${node.degree}` : null].filter(Boolean).join(" / ")
    const body = node.role === "focus" ? "この人物を中心に関係を描いています。" : "選ぶと人物ページを開きます。"

    return {
      eyebrow: node.role === "focus" ? "Focus" : "Person",
      title: node.label,
      meta,
      body,
      accessibleLabel: `${node.label}。${meta}。${body}`
    }
  }

  inspectorElementForEvent(event) {
    if (typeof event.composedPath === "function") {
      const matchingElement = event.composedPath().find((element) => element?.dataset?.inspectorTitle)
      if (matchingElement) return matchingElement
    }

    return this.inspectorElementFromNode(event.target)
  }

  inspectorElementFromNode(node) {
    let current = node

    while (current) {
      if (current.dataset?.inspectorTitle) return current
      current = current.parentNode
    }

    return null
  }

  updateInspectorFrom(element) {
    if (!this.hasInspectorTitleTarget) return

    this.inspectorEyebrowTarget.textContent = element.dataset.inspectorEyebrow || "Graph Guide"
    this.inspectorTitleTarget.textContent = element.dataset.inspectorTitle || this.defaultInspector().title
    this.inspectorMetaTarget.textContent = element.dataset.inspectorMeta || ""
    this.inspectorBodyTarget.textContent = element.dataset.inspectorBody || this.defaultInspector().body
  }

  resetInspector() {
    if (!this.hasInspectorTitleTarget) return

    const fallback = this.defaultInspector()
    this.inspectorEyebrowTarget.textContent = fallback.eyebrow
    this.inspectorTitleTarget.textContent = fallback.title
    this.inspectorMetaTarget.textContent = fallback.meta
    this.inspectorBodyTarget.textContent = fallback.body
  }

  defaultInspector() {
    if (this.graphValue?.variant === "cluster_overview") {
      return {
        eyebrow: "Map Guide",
        title: this.inspectorTitleValue || "クラスタを選んで詳細を見る",
        meta: this.inspectorMetaValue || "俯瞰 -> 選択 -> 詳細",
        body: this.inspectorBodyValue || "ノードはクラスタ、線はクラスタ間の接点です。気になるクラスタを選ぶと、下段に人物関係と構成情報が開きます。"
      }
    }

    return {
      eyebrow: "Graph Guide",
      title: this.inspectorTitleValue || "人物関係を読む",
      meta: this.inspectorMetaValue || "ノードを選ぶと人物ページを開きます",
      body: this.inspectorBodyValue || "hover / focus すると、人物や関係の説明を確認できます。"
    }
  }

  clusterPalette(category) {
    return this.clusterPaletteValue?.[category] || this.clusterPaletteValue?.other || {
      accent: "#7b8797",
      fill: "rgba(232, 236, 241, 0.94)",
      text: "#536071",
      halo: "rgba(123, 135, 151, 0.18)"
    }
  }

  escape(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
