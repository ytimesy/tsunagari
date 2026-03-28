require "set"

module DemoData
  class EncounterCaseGenerator
    DEFAULT_LIMIT = 12
    DEMO_TAGS = [ "デモ", "自動生成" ].freeze
    PARTICIPANT_ROLES = [ "initiator", "collaborator", "bridge" ].freeze
    OUTCOME_VARIANTS = [
      {
        category: "collaboration",
        outcome_direction: "positive",
        impact_scope: "team",
        evidence_level: "hypothesis",
        description_template: "%<left>s と %<right>s の共通点を起点に、%<outsider>s を交えた協働の可能性を検証するデモ事例。",
        insight_type: "enabler",
        insight_description_template: "共通点を持つ2名に、異質な第三者を加えると関係図にコントラストが生まれる。",
        application_note_template: "%<shared_label>s を持つ人物群に、異分野の参加者を1人足すと探索体験を確認しやすい。"
      },
      {
        category: "learning",
        outcome_direction: "mixed",
        impact_scope: "community",
        evidence_level: "reported",
        description_template: "近い専門性の対話は進みやすい一方で、%<outsider>s との接続には翻訳コストが生じる想定のデモ事例。",
        insight_type: "barrier",
        insight_description_template: "近い者同士だけでは探索が閉じ、異質な参加者だけでは接続理由が弱くなる。",
        application_note_template: "一覧確認時は、共通点と差異の両方が見える事例を混ぜると判断しやすい。"
      },
      {
        category: "innovation",
        outcome_direction: "unresolved",
        impact_scope: "field",
        evidence_level: "observed",
        description_template: "%<left>s と %<right>s の近さを基点にしつつ、%<outsider>s との異分野接続がどこまで成立するかを見るためのデモ事例。",
        insight_type: "lesson",
        insight_description_template: "人物録の厚みだけでは出会いの意味は見えにくく、事例の単位が必要になる。",
        application_note_template: "本番では実在出典に基づく encounter case を増やし、デモ事例は段階的に置き換える。"
      }
    ].freeze

    def self.generate!(limit: DEFAULT_LIMIT)
      new(limit: limit).generate!
    end

    def initialize(limit: DEFAULT_LIMIT, scope: Person.includes(:tags, :organizations).order(:display_name))
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
      @scope = scope
    end

    def generate!
      raise ArgumentError, "デモ事例を作るには少なくとも2人の人物が必要です。" if people.size < 2

      blueprints.first(@limit).map.with_index do |blueprint, index|
        upsert_case!(blueprint, index)
      end
    end

    private

    def blueprints
      @blueprints ||= begin
        plans = []
        used_signatures = Set.new

        shared_organization_groups.each do |organization_name, grouped_people|
          plan = build_mixed_plan(kind: :organization, label: organization_name, grouped_people: grouped_people)
          next unless plan
          next if used_signatures.include?(plan_signature(plan))

          plans << plan
          used_signatures << plan_signature(plan)
        end

        shared_tag_groups.each do |tag_name, grouped_people|
          plan = build_mixed_plan(kind: :tag, label: tag_name, grouped_people: grouped_people)
          next unless plan
          next if used_signatures.include?(plan_signature(plan))

          plans << plan
          used_signatures << plan_signature(plan)
        end

        if plans.size < @limit
          diverse_trios.each do |plan|
            next if used_signatures.include?(plan_signature(plan))

            plans << plan
            used_signatures << plan_signature(plan)
            break if plans.size >= @limit
          end
        end

        plans
      end
    end

    def build_mixed_plan(kind:, label:, grouped_people:)
      primary_people = grouped_people.first(2)
      outsider = pick_outsider_for(primary_people)
      participants = [ *primary_people, outsider ].compact.uniq { |person| person.id }
      return if participants.size < 2

      {
        kind: kind,
        label: label,
        participants: participants,
        shared_label: label,
        mixed: outsider.present?
      }
    end

    def diverse_trios
      plans = []

      people.combination(3) do |group|
        next unless pairwise_diverse?(group)

        plans << {
          kind: :diverse,
          label: "異分野接続",
          participants: group,
          shared_label: "共通点の薄い組み合わせ",
          mixed: false
        }
      end

      plans
    end

    def upsert_case!(blueprint, index)
      participant_names = blueprint[:participants].map(&:display_name)
      title = case_title(blueprint, participant_names, index)
      encounter_case = EncounterCase.find_or_initialize_by(title: title)
      variant = OUTCOME_VARIANTS[index % OUTCOME_VARIANTS.length]

      encounter_case.assign_attributes(
        summary: case_summary(blueprint, participant_names),
        background: case_background(blueprint),
        happened_on: Date.current - index.weeks,
        place: case_place(blueprint),
        publication_status: "published",
        published_at: encounter_case.published_at || Time.current
      )
      encounter_case.save!

      sync_tags(encounter_case, blueprint)
      sync_participants(encounter_case, blueprint[:participants])
      sync_outcome(encounter_case, blueprint, variant, participant_names)
      sync_insight(encounter_case, blueprint, variant, participant_names)
      sync_source(encounter_case)
      sync_note(encounter_case)

      encounter_case
    end

    def sync_tags(encounter_case, blueprint)
      names = DEMO_TAGS.dup
      names << blueprint[:label]
      names << "異分野接続" if blueprint[:kind] == :diverse || blueprint[:mixed]

      encounter_case.tags = names.uniq.map do |name|
        Tag.find_or_create_by!(normalized_name: name.downcase) do |tag|
          tag.name = name
        end
      end
    end

    def sync_participants(encounter_case, participants)
      encounter_case.case_participants.destroy_all

      participants.each_with_index do |person, index|
        publish_person!(person)
        encounter_case.case_participants.create!(
          person: person,
          participation_role: PARTICIPANT_ROLES[index % PARTICIPANT_ROLES.length]
        )
      end
    end

    def sync_outcome(encounter_case, blueprint, variant, participant_names)
      encounter_case.case_outcomes.destroy_all

      encounter_case.case_outcomes.create!(
        category: variant[:category],
        outcome_direction: variant[:outcome_direction],
        impact_scope: variant[:impact_scope],
        evidence_level: variant[:evidence_level],
        description: format(
          variant[:description_template],
          left: participant_names.first,
          right: participant_names.second || participant_names.first,
          outsider: participant_names.third || "追加参加者"
        )
      )
    end

    def sync_insight(encounter_case, blueprint, variant, participant_names)
      encounter_case.case_insights.destroy_all

      encounter_case.case_insights.create!(
        insight_type: variant[:insight_type],
        description: format(
          variant[:insight_description_template],
          left: participant_names.first,
          right: participant_names.second || participant_names.first,
          outsider: participant_names.third || "追加参加者",
          shared_label: blueprint[:shared_label]
        ),
        application_note: format(
          variant[:application_note_template],
          left: participant_names.first,
          right: participant_names.second || participant_names.first,
          outsider: participant_names.third || "追加参加者",
          shared_label: blueprint[:shared_label]
        )
      )
    end

    def sync_source(encounter_case)
      encounter_case.case_sources.destroy_all

      source = Source.find_or_initialize_by(url: demo_source_url(encounter_case))
      source.title = "デモ生成ルール"
      source.source_type = "demo_generated"
      source.published_on = Date.current
      source.save!

      encounter_case.case_sources.create!(source: source, citation_note: "UI確認用の自動生成データ")
    end

    def sync_note(encounter_case)
      encounter_case.research_notes.where(note_kind: "hypothesis").destroy_all
      encounter_case.research_notes.create!(
        note_kind: "hypothesis",
        status: "reviewed",
        body: "この事例は公開人物データのタグと所属をもとに生成したデモです。実在の出来事を記述していません。"
      )
    end

    def publish_person!(person)
      return if person.publication_status == "published" && person.published_at.present?

      person.update!(
        publication_status: "published",
        published_at: person.published_at || Time.current
      )
    end

    def shared_organization_groups
      groups_from(people) { |person| organization_names_for(person) }
    end

    def shared_tag_groups
      groups_from(people) { |person| tag_names_for(person) }
    end

    def groups_from(collection)
      grouped = Hash.new { |hash, key| hash[key] = [] }

      collection.each do |record|
        yield(record).each do |label|
          grouped[label] << record unless grouped[label].include?(record)
        end
      end

      grouped.select { |_label, grouped_people| grouped_people.size >= 2 }
             .sort_by { |label, grouped_people| [ -grouped_people.size, label ] }
    end

    def pick_outsider_for(participants)
      people.find do |candidate|
        next if participants.any? { |person| person.id == candidate.id }

        participants.all? do |person|
          (tag_names_for(person) & tag_names_for(candidate)).empty? &&
            (organization_names_for(person) & organization_names_for(candidate)).empty?
        end
      end
    end

    def pairwise_diverse?(group)
      group.combination(2).all? do |left, right|
        (tag_names_for(left) & tag_names_for(right)).empty? &&
          (organization_names_for(left) & organization_names_for(right)).empty?
      end
    end

    def case_title(blueprint, participant_names, index)
      case blueprint[:kind]
      when :organization
        "デモ事例 #{index + 1}: #{blueprint[:label]} を起点にした接続検証"
      when :tag
        "デモ事例 #{index + 1}: #{blueprint[:label]} まわりの連携仮説"
      else
        "デモ事例 #{index + 1}: #{participant_names.first} から広げる異分野接続"
      end
    end

    def case_summary(blueprint, participant_names)
      <<~TEXT.squish
        UI確認用に自動生成したデモ事例です。
        #{participant_names.join('、')} の公開プロフィールにある所属やタグから、
        関係図の見え方を確認するための仮想的な出会いの場面を作っています。
        実在の出来事を記述したものではありません。
      TEXT
    end

    def case_background(blueprint)
      basis =
        case blueprint[:kind]
        when :organization
          "共通所属"
        when :tag
          "共通タグ"
        else
          "差異の大きいプロフィール"
        end

      "#{basis} を手がかりにしつつ、青と黄の線がどのように出るかを確認するためのデモです。"
    end

    def case_place(blueprint)
      case blueprint[:kind]
      when :organization
        blueprint[:label]
      when :tag
        "#{blueprint[:label]} の勉強会"
      else
        "越境対話セッション"
      end
    end

    def demo_source_url(encounter_case)
      "https://example.org/tsunagari/demo-cases/#{encounter_case.slug}"
    end

    def plan_signature(plan)
      [ plan[:kind], plan[:label], plan[:participants].map(&:id).sort ]
    end

    def tag_names_for(person)
      person.tags.map(&:name)
    end

    def organization_names_for(person)
      person.organizations.map(&:name)
    end

    def people
      @people ||= @scope.to_a
    end
  end
end
