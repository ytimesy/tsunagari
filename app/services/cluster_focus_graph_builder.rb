class ClusterFocusGraphBuilder
  MAX_NEIGHBORS = 6

  def initialize(graph:, selected_cluster_slug:, query: nil)
    @graph = graph || {}
    @selected_cluster_slug = selected_cluster_slug.to_s.presence
    @query = query.to_s.strip.presence
  end

  def payload
    return unless selected_node.present? && neighbor_edges.any?

    {
      centerId: @selected_cluster_slug,
      nodes: focus_nodes,
      edges: neighbor_edges.map(&:dup),
      layout: "rings",
      labelMode: "all",
      variant: "cluster_overview",
      ariaLabel: "#{selected_node[:label]} 周辺クラスタとの接点マップ"
    }
  end

  def connections
    return [] unless payload

    neighbor_edges.map do |edge|
      neighbor = neighbor_for(edge)

      {
        slug: neighbor[:id],
        label: neighbor[:label],
        category_label: neighbor[:categoryLabel],
        pair_count: edge[:pairCount] || edge[:weight] || 0,
        tone_label: edge[:toneLabel],
        kind_label: edge[:kindLabel],
        shared_organizations: Array(edge[:sharedOrganizations]),
        shared_tags: Array(edge[:sharedTags]),
        href: cluster_href(neighbor[:id])
      }
    end
  end

  private

  def focus_nodes
    focus_node_ids.filter_map do |node_id|
      node = node_index[node_id]
      next unless node

      node.merge(
        role: node_id == @selected_cluster_slug ? "focus" : "cluster",
        selected: node_id == @selected_cluster_slug
      )
    end
  end

  def focus_node_ids
    @focus_node_ids ||= ([ @selected_cluster_slug ] + neighbor_edges.flat_map { |edge| [ edge[:source], edge[:target] ] }).uniq
  end

  def neighbor_edges
    @neighbor_edges ||= Array(@graph[:edges]).select do |edge|
      edge[:source] == @selected_cluster_slug || edge[:target] == @selected_cluster_slug
    end.sort_by do |edge|
      [ -(edge[:pairCount] || edge[:weight] || 0), edge[:sourceLabel].to_s, edge[:targetLabel].to_s ]
    end.first(MAX_NEIGHBORS)
  end

  def selected_node
    node_index[@selected_cluster_slug]
  end

  def neighbor_for(edge)
    node_id = edge[:source] == @selected_cluster_slug ? edge[:target] : edge[:source]
    fallback_label = edge[:source] == @selected_cluster_slug ? edge[:targetLabel] : edge[:sourceLabel]

    node_index.fetch(node_id, { id: node_id, label: fallback_label })
  end

  def node_index
    @node_index ||= Array(@graph[:nodes]).index_by { |node| node[:id] }
  end

  def cluster_href(cluster_slug)
    params = { cluster: cluster_slug }
    params[:q] = @query if @query.present?
    Rails.application.routes.url_helpers.graph_people_path(**params)
  end
end
