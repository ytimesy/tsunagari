require "test_helper"

class UserFlowsTest < ActionDispatch::IntegrationTest
  test "editor can create and update a person" do
    sign_in_as(create_user)

    get new_person_path
    assert_response :success
    assert_match "標準分野カタログ", response.body
    assert_match "100", response.body
    assert_match "社会・公共", response.body
    assert_match "AI", response.body

    post people_path, params: {
      person: {
        display_name: "Ada Lovelace",
        summary: "Poetical science pioneer",
        bio: "Known for linking imagination and computation.",
        recommended_for: "計算文化を語る企画、創造性と技術の交差点を探る場",
        meeting_value: "概念の翻訳や、技術と物語をつなぐ相談に価値があります。",
        fit_modes: "登壇向き, 取材向き",
        introduction_note: "技術史の導入役として紹介すると入りやすいです。",
        last_reviewed_on: Date.new(2026, 4, 4),
        publication_status: "published",
        tag_list: "Math, Computing",
        primary_organization_name: "Analytical Society",
        primary_organization_category: "community",
        primary_affiliation_title: "Member"
      }
    }

    person = Person.find_by!(display_name: "Ada Lovelace")
    assert_redirected_to person_path(person)
    assert_equal [ "Computing", "Math" ], person.tags.order(:name).pluck(:name)
    assert_equal "計算文化を語る企画、創造性と技術の交差点を探る場", person.recommended_for
    assert_equal "登壇向き, 取材向き", person.fit_modes
    assert_equal [ "created" ], person.edit_histories.pluck(:action)
    assert_match "人物情報", person.edit_histories.last.summary

    patch person_path(person), params: {
      person: {
        display_name: "Ada Lovelace",
        summary: "Poetical science pioneer and editor",
        bio: "Known for linking imagination and computation.",
        recommended_for: "技術史と編集の接点を考える企画",
        meeting_value: "技術の意味づけや編集方針を相談する価値があります。",
        fit_modes: "登壇向き, 共同研究向き",
        introduction_note: "編集者や研究者と組み合わせると話が深まりやすいです。",
        last_reviewed_on: Date.new(2026, 4, 5),
        publication_status: "review",
        tag_list: "Math, Computing, Writing",
        primary_organization_name: "Analytical Society",
        primary_organization_category: "community",
        primary_affiliation_title: "Member"
      }
    }

    assert_redirected_to edit_person_path(person)
    assert_equal "review", person.reload.publication_status
    assert_equal [ "Computing", "Math", "Writing" ], person.tags.order(:name).pluck(:name)
    assert_equal "技術史と編集の接点を考える企画", person.recommended_for
    assert_equal "登壇向き, 共同研究向き", person.fit_modes
    assert_equal %w[created updated], person.edit_histories.order(:created_at).pluck(:action)
    assert_match "活用視点", person.edit_histories.recent.first.summary

    get person_path(person)
    assert_response :success
    assert_match "この人物の活用視点", response.body
    assert_match "仮説の人物像", response.body
    assert_match "公開情報ベースの見立て", response.body
    assert_match "性格や年収などの私的属性は推定しません", response.body
    assert_match "技術史と編集の接点を考える企画", response.body
    assert_match "登壇向き", response.body
    assert_match "紹介メモ", response.body
  end

  test "wiki shows draft and review people to general visitors by default while archived records stay hidden" do
    public_person = Person.create!(display_name: "Public Person", publication_status: "published")
    draft_person = Person.create!(display_name: "Draft Person", publication_status: "draft")
    review_person = Person.create!(display_name: "Review Person", publication_status: "review")
    archived_person = Person.create!(display_name: "Archived Person", publication_status: "archived")

    get root_path
    assert_response :success
    assert_match "#{Person.publicly_visible.count} 人物", response.body

    get people_path
    assert_response :success
    assert_match "Public Person", response.body
    assert_match "Draft Person", response.body
    assert_match "Review Person", response.body
    assert_no_match "Archived Person", response.body

    get person_path(public_person)
    assert_response :success

    get person_path(draft_person)
    assert_response :success

    get person_path(review_person)
    assert_response :success

    get person_path(archived_person)
    assert_response :not_found
  end

  test "wiki hides draft and review people from general visitors when strict public visibility is enabled" do
    public_person = Person.create!(display_name: "Strict Public Person", publication_status: "published")
    draft_person = Person.create!(display_name: "Strict Draft Person", publication_status: "draft")
    review_person = Person.create!(display_name: "Strict Review Person", publication_status: "review")
    archived_person = Person.create!(display_name: "Strict Archived Person", publication_status: "archived")

    with_stubbed_method(TsunagariFeatureFlags, :strict_public_visibility?, true) do
      get root_path
      assert_response :success
      assert_match "#{Person.publicly_visible.count} 人物", response.body

      get people_path
      assert_response :success
      assert_match "Strict Public Person", response.body
      assert_no_match "Strict Draft Person", response.body
      assert_no_match "Strict Review Person", response.body
      assert_no_match "Strict Archived Person", response.body

      get person_path(public_person)
      assert_response :success

      get person_path(draft_person)
      assert_response :not_found

      get person_path(review_person)
      assert_response :not_found

      get person_path(archived_person)
      assert_response :not_found
    end
  end

test "global people graph still uses non-archived people when strict public visibility is enabled" do
  published_person = Person.create!(display_name: "Strict Visible Person", publication_status: "published")
  draft_person = Person.create!(display_name: "Strict Draft Collaborator", publication_status: "draft")
  archived_person = Person.create!(display_name: "Strict Archived Collaborator", publication_status: "archived")

  organization = Organization.create!(name: "Community Lab", slug: "community-lab", category: "community")
  PersonAffiliation.create!(person: published_person, organization: organization, primary_flag: true)
  PersonAffiliation.create!(person: draft_person, organization: organization, primary_flag: true)
  PersonAffiliation.create!(person: archived_person, organization: organization, primary_flag: true)

  with_stubbed_method(TsunagariFeatureFlags, :strict_public_visibility?, true) do
    get graph_people_path(cluster: "org-community-lab")

    assert_response :success
    assert_match "Community Lab", response.body
    assert_match "Strict Visible Person", response.body
    assert_match "Strict Draft Collaborator", response.body
    assert_no_match "Strict Archived Collaborator", response.body
  end
end

  test "editor can add research notes to person" do
    sign_in_as(create_user)

    person = Person.create!(display_name: "Grace Hopper", publication_status: "published")

    post research_notes_path, params: {
      research_note: {
        person_id: person.id,
        note_kind: "research",
        body: "Follow up with an oral history source."
      }
    }

    assert_redirected_to person_path(person)
    assert_equal 1, person.research_notes.count
  end

  test "person detail uses fit modes and insight topics to build local relationships" do
    ada = Person.create!(
      display_name: "Ada Lovelace",
      publication_status: "published",
      fit_modes: "登壇向き, 相談向き",
      recommended_for: "AI の企画を整理する会話に向いています。"
    )
    babbage = Person.create!(
      display_name: "Charles Babbage",
      publication_status: "published",
      fit_modes: "登壇向き",
      meeting_value: "AI と計算機の話題を深められます。"
    )

    get person_path(ada)

    assert_response :success
    assert_match "人物起点マップ", response.body
    assert_match "charles-babbage", response.body
    assert_match(/共通テーマ: .*登壇向き/, response.body)
    assert_match(/共通テーマ: .*AI/, response.body)
  end

  test "global people graph uses fit modes and insight topics for local-only people" do
    Person.create!(
      display_name: "Ada Lovelace",
      publication_status: "published",
      fit_modes: "登壇向き, 相談向き",
      recommended_for: "AI の企画を整理する会話に向いています。"
    )
    Person.create!(
      display_name: "Charles Babbage",
      publication_status: "published",
      fit_modes: "登壇向き",
      meeting_value: "AI と計算機の話題を深められます。"
    )
    Person.create!(
      display_name: "Grace Hopper",
      publication_status: "published",
      fit_modes: "登壇向き",
      introduction_note: "AI とソフトウェアの橋渡し役として紹介しやすいです。"
    )

    get graph_people_path

    assert_response :success
    assert_match "登壇向き", response.body
    assert_match "tag-", response.body
  end

  test "person detail shows relationship map around the focal person" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")
    computing = Tag.create!(name: "Computing")
    community = Tag.create!(name: "Community Design")
    ada.tags << computing
    babbage.tags << computing
    helper.tags << [ computing, community ]

    get person_path(ada)
    assert_response :success
    assert_match "人物起点マップ", response.body
    assert_match "人物関係図", response.body
    assert_match "主要関係者", response.body
    assert_match "関係の理由", response.body
    assert_match "次に見るべき人物", response.body
    assert_no_match "関連事例", response.body
    assert_match "公開情報ベースの見立て", response.body
    assert_match "活動特性スケール", response.body
    assert_match "分析性", response.body
    assert_match "関係の持ち方", response.body
    assert_match "共通テーマ: Computing", response.body
    assert_match "ada-lovelace", response.body
    assert_match "charles-babbage", response.body
    assert_match "community-organizer", response.body
  end

  test "person detail can expand the relationship map to second and third hop" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    kay = Person.create!(display_name: "Alan Kay", publication_status: "published")

    computing = Tag.create!(name: "Computing")
    engines = Tag.create!(name: "Engines")
    compilers = Tag.create!(name: "Compilers")
    objects = Tag.create!(name: "Objects")

    ada.tags << computing
    babbage.tags << [ computing, engines ]
    grace.tags << [ engines, compilers ]
    kay.tags << [ compilers, objects ]

    get person_path(ada)
    assert_response :success
    assert_match "charles-babbage", response.body
    assert_match "grace-hopper", response.body
    assert_match "alan-kay", response.body
    assert_match 'data-relationship-depth-active-depth-value="1"', response.body
    assert_match(/data-depth="2"\s+hidden/, response.body)

    get person_path(ada, graph_depth: 2)
    assert_response :success
    assert_match 'data-relationship-depth-active-depth-value="2"', response.body
    assert_match "grace-hopper", response.body

    get person_path(ada, graph_depth: 3)
    assert_response :success
    assert_match 'data-relationship-depth-active-depth-value="3"', response.body
    assert_match "alan-kay", response.body
  end

  test "graph page offers a compact toggle for people who want the diagrams first" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")

    [
      [ ada, "openalex", "A123" ],
      [ babbage, "openalex", "A456" ]
    ].each do |person, source_name, external_id|
      person.person_external_profiles.create!(
        source_name: source_name,
        external_id: external_id,
        source_url: "https://example.test/#{external_id}",
        fetched_at: Time.current,
        graph_tags: [ "Computing" ],
        graph_organizations: [ "Analytical Society" ]
      )
    end

    get graph_people_path

    assert_response :success
    assert_match 'data-controller="graph-density"', response.body
    assert_match "説明を省略", response.body
    assert_match 'data-graph-density-target="collapsible"', response.body
  end

  test "global people graph includes local-only people with shared affiliations" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")

    organization = Organization.create!(name: "Community Lab", slug: "community-lab", category: "community")
    PersonAffiliation.create!(person: ada, organization: organization, primary_flag: true)
    PersonAffiliation.create!(person: babbage, organization: organization, primary_flag: true)

    get graph_people_path

    assert_response :success
    assert_match "Community Lab", response.body
    assert_match "org-community-lab", response.body
  end

  test "global people graph shows imported network" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Mathematics" ],
      graph_organizations: [ "Analytical Society" ]
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A456",
      source_url: "https://openalex.org/A456",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Analytical Society" ]
    )
    helper.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q789",
      source_url: "https://www.wikidata.org/wiki/Q789",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Civic Design" ],
      graph_organizations: [ "Civic Lab" ]
    )
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q111",
      source_url: "https://www.wikidata.org/wiki/Q111",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Civic Lab" ]
    )

    get graph_people_path

    assert_response :success
    assert_match "全体関係マップ", response.body
    assert_match "構造レンズ", response.body
    assert_match "主要クラスタ", response.body
    assert_match "org-analytical-society", response.body
    assert_match "org-civic-lab", response.body
    assert_match "Analytical Society", response.body
    assert_match "Civic Lab", response.body
  end

  test "global people graph still renders imported nodes when lightweight graph cache is empty" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    curie = Person.create!(display_name: "Marie Curie", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current
    )
    curie.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q7186",
      source_url: "https://www.wikidata.org/wiki/Q7186",
      fetched_at: Time.current
    )

    get graph_people_path

    assert_response :success
    assert_match "全体関係マップ", response.body
    assert_match 'data-controller="relationship-graph"', response.body
    assert_match "cluster=other", response.body
    assert_match "その他", response.body
    assert_no_match "共通タグや所属が増えると全体ネットワークを描画できます。", response.body
  end

  test "global people graph resolves live metadata for large overview requests" do
    80.times do |index|
      person = Person.create!(display_name: "Imported Person #{index}", publication_status: "published")
      person.person_external_profiles.create!(
        source_name: "openalex",
        external_id: "A#{index}",
        source_url: "https://openalex.org/A#{index}",
        fetched_at: Time.current
      )
    end

    resolved_people_count = 0
    resolver = Object.new
    resolver.define_singleton_method(:metadata_index_for) do |people|
      resolved_people_count = people.length

      Array(people).each_with_object({}) do |person, index|
        person_number = person.display_name.split.last.to_i
        organization = person_number.even? ? "Analytical Society" : "Civic Lab"

        index[person.id] = {
          tags: [ "Computing" ],
          organizations: [ organization ]
        }
      end
    end

    with_stubbed_method(ExternalPeople::ProfileResolver, :new, resolver) do
      get graph_people_path
    end

    assert_response :success
    assert_equal 80, resolved_people_count
    assert_match "全体関係マップ", response.body
    assert_match "org-analytical-society", response.body
    assert_match "org-civic-lab", response.body
  end

  test "graph page chooses a non-isolated person for the person focus map when available" do
    isolated = Person.create!(display_name: "Isolated Star", publication_status: "published")

    connected_host = Person.create!(display_name: "Connected Host", publication_status: "published")
    connected_guest = Person.create!(display_name: "Connected Guest", publication_status: "published")
    organization = Organization.create!(name: "Community Lab", slug: "community-lab", category: "community")
    PersonAffiliation.create!(person: connected_host, organization: organization, primary_flag: true)
    PersonAffiliation.create!(person: connected_guest, organization: organization, primary_flag: true)

    get graph_people_path

    assert_response :success
    assert_match person_path(connected_host), response.body
    assert_no_match person_path(isolated), response.body
  end

  test "graph page shows concrete diagram candidates" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")

    [
      [ ada, "openalex", "A123", [ "Computing", "Mathematics" ], [ "Analytical Society" ] ],
      [ babbage, "openalex", "A456", [ "Computing" ], [ "Analytical Society" ] ],
      [ grace, "wikidata", "Q111", [ "Compilers", "Computing" ], [ "Navy Lab" ] ]
    ].each do |person, source_name, external_id, tags, organizations|
      person.person_external_profiles.create!(
        source_name: source_name,
        external_id: external_id,
        source_url: "https://example.test/#{external_id}",
        fetched_at: Time.current,
        graph_tags: tags,
        graph_organizations: organizations
      )
    end

    get graph_people_path

    assert_response :success
    assert_match "全体の規模", response.body
    assert_match "構造レンズ", response.body
    assert_match "参考ビュー", response.body
    assert_match "人物起点マップ", response.body
    assert_no_match "出会いフロー図", response.body
    assert_match "全体構造図", response.body
    assert_match person_path(ada), response.body
    assert_match "周辺人物", response.body
  end

  test "selected cluster shows member details" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")

    ada.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A123",
      source_url: "https://openalex.org/A123",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Mathematics" ],
      graph_organizations: [ "Analytical Society" ]
    )
    babbage.person_external_profiles.create!(
      source_name: "openalex",
      external_id: "A456",
      source_url: "https://openalex.org/A456",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Analytical Society" ]
    )
    grace.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q111",
      source_url: "https://www.wikidata.org/wiki/Q111",
      fetched_at: Time.current,
      graph_tags: [ "Computing" ],
      graph_organizations: [ "Civic Lab" ]
    )
    helper.person_external_profiles.create!(
      source_name: "wikidata",
      external_id: "Q789",
      source_url: "https://www.wikidata.org/wiki/Q789",
      fetched_at: Time.current,
      graph_tags: [ "Computing", "Civic Design" ],
      graph_organizations: [ "Civic Lab" ]
    )

    get graph_people_path(cluster: "org-analytical-society")

    assert_response :success
    assert_match "選択クラスタ詳細", response.body
    assert_match "Ada Lovelace", response.body
    assert_match "Charles Babbage", response.body
    assert_match "人物レンズ", response.body
    assert_match "重なりレンズ", response.body
    assert_match "共通人物なし", response.body
    assert_match "越境レンズ", response.body
    assert_match "越境の強い行き先", response.body
    assert_match "Civic Lab", response.body
    assert_match 'labelMode&quot;:&quot;all', response.body
    assert_match person_path(ada, cluster: "org-analytical-society"), response.body
  end

  test "selected cluster still shows a relationship graph when the cluster is large" do
    61.times do |index|
      person = Person.create!(display_name: format("Researcher %02d", index), publication_status: "published")

      person.person_external_profiles.create!(
        source_name: "openalex",
        external_id: "A#{index}",
        source_url: "https://openalex.org/A#{index}",
        fetched_at: Time.current,
        graph_tags: [ "Computing", ("Mathematics" if index < 40), ("Systems" if index.even?) ].compact,
        graph_organizations: [ "Analytical Society", ("Logic Lab" if index < 20) ].compact
      )
    end

    get graph_people_path(cluster: "org-analytical-society")

    assert_response :success
    assert_match "人物レンズ", response.body
    assert_match "接点が多い 60 人を選んで描画しています", response.body
    assert_no_match "人数が多いため、部分関係図は省略しています", response.body
  end
end
