require "test_helper"

class ClusterFocusGraphBuilderTest < ActiveSupport::TestCase
  test "extracts a selected cluster focused graph and connection summary" do
    graph = {
      centerId: "org-analytical-society",
      nodes: [
        { id: "org-analytical-society", label: "Analytical Society", category: "organization", categoryLabel: "所属クラスタ", selected: true },
        { id: "org-civic-lab", label: "Civic Lab", category: "organization", categoryLabel: "所属クラスタ" },
        { id: "tag-computing", label: "Computing", category: "tag", categoryLabel: "分野クラスタ" },
        { id: "other", label: "その他", category: "other", categoryLabel: "補助クラスタ" }
      ],
      edges: [
        { source: "org-analytical-society", target: "org-civic-lab", sourceLabel: "Analytical Society", targetLabel: "Civic Lab", weight: 4, pairCount: 4, toneLabel: "越境的な接点", kindLabel: "分野横断", sharedOrganizations: [ "Civic Lab" ], sharedTags: [ "Computing" ] },
        { source: "org-analytical-society", target: "tag-computing", sourceLabel: "Analytical Society", targetLabel: "Computing", weight: 2, pairCount: 2, toneLabel: "近い文脈", kindLabel: "近縁", sharedOrganizations: [], sharedTags: [ "Computing" ] },
        { source: "other", target: "tag-computing", sourceLabel: "その他", targetLabel: "Computing", weight: 9, pairCount: 9, toneLabel: "越境的な接点", kindLabel: "補助", sharedOrganizations: [], sharedTags: [ "Networks" ] }
      ]
    }

    builder = ClusterFocusGraphBuilder.new(graph: graph, selected_cluster_slug: "org-analytical-society", query: "ada")
    payload = builder.payload
    connections = builder.connections

    assert_equal "org-analytical-society", payload[:centerId]
    assert_equal "cluster_overview", payload[:variant]
    assert_equal [ "org-analytical-society", "org-civic-lab", "tag-computing" ].sort, payload[:nodes].map { |node| node[:id] }.sort
    assert_equal 2, payload[:edges].length
    assert_equal "focus", payload[:nodes].find { |node| node[:id] == "org-analytical-society" }[:role]
    assert_equal [ "Civic Lab", "Computing" ], connections.map { |connection| connection[:label] }
    assert_equal Rails.application.routes.url_helpers.graph_people_path(cluster: "org-civic-lab", q: "ada"), connections.first[:href]
    assert_equal [ "Computing" ], connections.first[:shared_tags]
  end

  test "returns nothing when the selected cluster is missing or isolated" do
    builder = ClusterFocusGraphBuilder.new(
      graph: {
        nodes: [ { id: "org-analytical-society", label: "Analytical Society", category: "organization", categoryLabel: "所属クラスタ" } ],
        edges: []
      },
      selected_cluster_slug: "org-analytical-society"
    )

    assert_nil builder.payload
    assert_equal [], builder.connections
  end
end
