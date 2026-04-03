require "test_helper"

class UserFlowsTest < ActionDispatch::IntegrationTest
  test "editor can create and update a person and encounter case" do
    sign_in_as(create_user)

    get new_person_path
    assert_response :success

    post people_path, params: {
      person: {
        display_name: "Ada Lovelace",
        summary: "Poetical science pioneer",
        bio: "Known for linking imagination and computation.",
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
    assert_equal [ "created" ], person.edit_histories.pluck(:action)
    assert_match "人物情報", person.edit_histories.last.summary

    patch person_path(person), params: {
      person: {
        display_name: "Ada Lovelace",
        summary: "Poetical science pioneer and editor",
        bio: "Known for linking imagination and computation.",
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
    assert_equal %w[created updated], person.edit_histories.order(:created_at).pluck(:action)
    assert_match "タグ", person.edit_histories.recent.first.summary

    get new_encounter_case_path
    assert_response :success

    post encounter_cases_path, params: {
      encounter_case: {
        title: "Ada and Charles started a new line of inquiry",
        summary: "A meeting that pushed analytical work forward.",
        background: "They met around shared interest in machines.",
        happened_on: Date.new(1843, 1, 1),
        place: "London",
        publication_status: "published",
        tag_list: "Collaboration, Innovation",
        participant_names: "Ada Lovelace, Charles Babbage",
        participant_role: "participant",
        outcome_category: "innovation",
        outcome_direction: "positive",
        outcome_description: "A new computational perspective emerged.",
        impact_scope: "field",
        evidence_level: "documented",
        insight_type: "enabler",
        insight_description: "They had a shared curiosity and technical depth.",
        application_note: "Shared inquiry spaces matter.",
        source_title: "Biography",
        source_url: "https://example.com/ada-charles",
        source_type: "article",
        source_published_on: Date.new(2024, 1, 1)
      }
    }

    encounter_case = EncounterCase.find_by!(title: "Ada and Charles started a new line of inquiry")
    assert_redirected_to encounter_case_path(encounter_case)
    assert_equal 2, encounter_case.people.count
    assert_equal "positive", encounter_case.case_outcomes.first.outcome_direction
    assert_equal [ "created" ], encounter_case.edit_histories.pluck(:action)

    get encounter_case_path(encounter_case)
    assert_response :success
    assert_match "人物関係図", response.body
    assert_match "共創", response.body
    assert_match "情報源", response.body
    assert_match "編集履歴", response.body
    assert_match "Biography", response.body
    assert_match "Ada Lovelace", response.body
    assert_match "Charles Babbage", response.body

    patch encounter_case_path(encounter_case), params: {
      encounter_case: {
        title: "Ada and Charles started a new line of inquiry",
        summary: "The meeting led to a more explicit computational framing.",
        background: "They met around shared interest in machines.",
        happened_on: Date.new(1843, 1, 1),
        place: "London / correspondence",
        publication_status: "review",
        tag_list: "Collaboration, Innovation",
        participant_names: "Ada Lovelace, Charles Babbage",
        participant_role: "participant",
        outcome_category: "innovation",
        outcome_direction: "mixed",
        outcome_description: "A new computational perspective emerged, but adoption remained limited.",
        impact_scope: "field",
        evidence_level: "documented",
        insight_type: "lesson",
        insight_description: "Strong ideas still need translation into institutions.",
        application_note: "Pair original thinkers with implementers earlier.",
        source_title: "Biography",
        source_url: "https://example.com/ada-charles",
        source_type: "article",
        source_published_on: Date.new(2024, 1, 1)
      }
    }

    assert_redirected_to edit_encounter_case_path(encounter_case)
    assert_equal "review", encounter_case.reload.publication_status
    assert_equal "mixed", encounter_case.case_outcomes.first.outcome_direction
    assert_equal %w[created updated], encounter_case.edit_histories.order(:created_at).pluck(:action)
    assert_match "結果", encounter_case.edit_histories.recent.first.summary
  end

  test "wiki shows draft and review records to general visitors by default while archived records stay hidden" do
    public_person = Person.create!(display_name: "Public Person", publication_status: "published")
    draft_person = Person.create!(display_name: "Draft Person", publication_status: "draft")
    review_person = Person.create!(display_name: "Review Person", publication_status: "review")
    archived_person = Person.create!(display_name: "Archived Person", publication_status: "archived")
    public_case = EncounterCase.create!(title: "Public Case", publication_status: "published")
    draft_case = EncounterCase.create!(title: "Draft Case", publication_status: "draft")
    review_case = EncounterCase.create!(title: "Review Case", publication_status: "review")
    archived_case = EncounterCase.create!(title: "Archived Case", publication_status: "archived")

    get root_path
    assert_response :success
    assert_match "#{Person.publicly_visible.count} 人物", response.body
    assert_match "#{EncounterCase.publicly_visible.count} 事例", response.body

    get people_path
    assert_response :success
    assert_match "Public Person", response.body
    assert_match "Draft Person", response.body
    assert_match "Review Person", response.body
    assert_no_match "Archived Person", response.body

    get encounter_cases_path
    assert_response :success
    assert_match "Public Case", response.body
    assert_match "Draft Case", response.body
    assert_match "Review Case", response.body
    assert_no_match "Archived Case", response.body

    get person_path(public_person)
    assert_response :success

    get person_path(draft_person)
    assert_response :success

    get person_path(review_person)
    assert_response :success

    get person_path(archived_person)
    assert_response :not_found

    get encounter_case_path(public_case)
    assert_response :success

    get encounter_case_path(draft_case)
    assert_response :success

    get encounter_case_path(review_case)
    assert_response :success

    get encounter_case_path(archived_case)
    assert_response :not_found
  end

  test "wiki hides draft and review records from general visitors when strict public visibility is enabled" do
    public_person = Person.create!(display_name: "Strict Public Person", publication_status: "published")
    draft_person = Person.create!(display_name: "Strict Draft Person", publication_status: "draft")
    review_person = Person.create!(display_name: "Strict Review Person", publication_status: "review")
    archived_person = Person.create!(display_name: "Strict Archived Person", publication_status: "archived")
    public_case = EncounterCase.create!(title: "Strict Public Case", publication_status: "published")
    draft_case = EncounterCase.create!(title: "Strict Draft Case", publication_status: "draft")
    review_case = EncounterCase.create!(title: "Strict Review Case", publication_status: "review")
    archived_case = EncounterCase.create!(title: "Strict Archived Case", publication_status: "archived")

    with_stubbed_method(TsunagariFeatureFlags, :strict_public_visibility?, true) do
      get root_path
      assert_response :success
      assert_match "#{Person.publicly_visible.count} 人物", response.body
      assert_match "#{EncounterCase.publicly_visible.count} 事例", response.body

      get people_path
      assert_response :success
      assert_match "Strict Public Person", response.body
      assert_no_match "Strict Draft Person", response.body
      assert_no_match "Strict Review Person", response.body
      assert_no_match "Strict Archived Person", response.body

      get encounter_cases_path
      assert_response :success
      assert_match "Strict Public Case", response.body
      assert_no_match "Strict Draft Case", response.body
      assert_no_match "Strict Review Case", response.body
      assert_no_match "Strict Archived Case", response.body

      get person_path(public_person)
      assert_response :success

      get person_path(draft_person)
      assert_response :not_found

      get person_path(review_person)
      assert_response :not_found

      get person_path(archived_person)
      assert_response :not_found

      get encounter_case_path(public_case)
      assert_response :success

      get encounter_case_path(draft_case)
      assert_response :not_found

      get encounter_case_path(review_case)
      assert_response :not_found

      get encounter_case_path(archived_case)
      assert_response :not_found
    end
  end

  test "editor can add research notes to person and encounter case" do
    sign_in_as(create_user)

    person = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    encounter_case = EncounterCase.create!(title: "Grace met a Navy team", publication_status: "published")

    post research_notes_path, params: {
      research_note: {
        person_id: person.id,
        note_kind: "research",
        body: "Follow up with an oral history source."
      }
    }

    assert_redirected_to person_path(person)
    assert_equal 1, person.research_notes.count

    post research_notes_path, params: {
      research_note: {
        encounter_case_id: encounter_case.id,
        note_kind: "hypothesis",
        body: "Trust and institutional backing seem central."
      }
    }

    assert_redirected_to encounter_case_path(encounter_case)
    assert_equal 1, encounter_case.research_notes.count
  end

  test "case detail shows setbacks and lessons without login" do
    encounter_case = EncounterCase.create!(
      title: "A civic project stalled after an initial meeting",
      summary: "The meeting created energy, but the collaboration later stalled.",
      publication_status: "published"
    )
    encounter_case.case_outcomes.create!(
      category: "coordination",
      outcome_direction: "negative",
      description: "The project stalled because ownership stayed ambiguous.",
      evidence_level: "reported"
    )
    encounter_case.case_insights.create!(
      insight_type: "barrier",
      description: "Ambiguous roles and delayed decisions weakened trust.",
      application_note: "Set decision owners before the first collaborative sprint."
    )

    get encounter_case_path(encounter_case)
    assert_response :success
    assert_match "失敗・後退", response.body
    assert_match "阻害要因", response.body
    assert_match "ownership stayed ambiguous", response.body
    assert_match "追記メモの閲覧と記入は、編集者ログイン後に利用できます。", response.body
    assert_no_match "メモを残す", response.body
  end

  test "person detail shows relationship map around the focal person" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    helper = Person.create!(display_name: "Community Organizer", publication_status: "published")
    computing = Tag.create!(name: "Computing")
    ada.tags << computing
    babbage.tags << computing

    encounter_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    encounter_case.case_participants.create!(person: ada, participation_role: "participant")
    encounter_case.case_participants.create!(person: babbage, participation_role: "participant")
    encounter_case.case_participants.create!(person: helper, participation_role: "bridge")
    encounter_case.case_outcomes.create!(category: "prototype", outcome_direction: "positive", description: "試作が前に進んだ")

    get person_path(ada)
    assert_response :success
    assert_match "人物起点マップ", response.body
    assert_match "人物関係図", response.body
    assert_match "近い人物", response.body
    assert_match "越境人物", response.body
    assert_match "関連事例", response.body
    assert_match "ada-lovelace", response.body
    assert_match "charles-babbage", response.body
    assert_match "community-organizer", response.body
    assert_match encounter_case_path(encounter_case), response.body
  end

  test "person detail can expand the relationship map to second and third hop" do
    ada = Person.create!(display_name: "Ada Lovelace", publication_status: "published")
    babbage = Person.create!(display_name: "Charles Babbage", publication_status: "published")
    grace = Person.create!(display_name: "Grace Hopper", publication_status: "published")
    kay = Person.create!(display_name: "Alan Kay", publication_status: "published")

    direct_case = EncounterCase.create!(title: "Analytical exchange", publication_status: "published")
    direct_case.case_participants.create!(person: ada, participation_role: "participant")
    direct_case.case_participants.create!(person: babbage, participation_role: "participant")

    second_hop_case = EncounterCase.create!(title: "Compiler dialogue", publication_status: "published")
    second_hop_case.case_participants.create!(person: babbage, participation_role: "participant")
    second_hop_case.case_participants.create!(person: grace, participation_role: "participant")

    third_hop_case = EncounterCase.create!(title: "Object systems forum", publication_status: "published")
    third_hop_case.case_participants.create!(person: grace, participation_role: "participant")
    third_hop_case.case_participants.create!(person: kay, participation_role: "participant")

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

    encounter_case = EncounterCase.create!(
      title: "Analytical Engine Session",
      publication_status: "published",
      published_at: Time.current,
      happened_on: Date.current,
      place: "London"
    )
    encounter_case.case_participants.create!(person: ada, participation_role: "host")
    encounter_case.case_participants.create!(person: babbage, participation_role: "guest")
    encounter_case.case_outcomes.create!(category: "prototype", outcome_direction: "positive", description: "試作が前に進んだ")
    encounter_case.case_insights.create!(insight_type: "lesson", description: "役割を明確にしたほうが進みやすい")

    tag = Tag.create!(name: "Computing", normalized_name: "computing")
    encounter_case.tags << tag

    get graph_people_path

    assert_response :success
    assert_match "見たい図の候補", response.body
    assert_match "人物起点マップ", response.body
    assert_match "出会いフロー図", response.body
    assert_match "全体構造図", response.body
    assert_match person_path(ada), response.body
    assert_match encounter_case_path(encounter_case), response.body
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
