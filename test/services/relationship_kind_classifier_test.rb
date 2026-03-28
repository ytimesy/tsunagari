require "test_helper"

class RelationshipKindClassifierTest < ActiveSupport::TestCase
  test "supports all 8 representative relationship kinds" do
    samples = {
      "same_field" => {
        shared_tags: [ "Computing", "Mathematics" ],
        shared_organizations: []
      },
      "same_organization" => {
        shared_tags: [],
        shared_organizations: [ "Analytical Society" ]
      },
      "co_creation" => {
        shared_tags: [ "Design" ],
        shared_organizations: [],
        shared_case_count: 1,
        shared_outcome_directions: [ "positive" ]
      },
      "succession" => {
        shared_tags: [],
        shared_organizations: [ "Atelier" ],
        text_fragments: [ "A mentor passed on a lineage of practice." ]
      },
      "inspiration" => {
        shared_tags: [],
        shared_organizations: [],
        shared_case_count: 1,
        shared_insight_types: [ "turning_point" ]
      },
      "crossing" => {
        shared_tags: [],
        shared_organizations: [],
        shared_case_count: 1
      },
      "support" => {
        shared_tags: [],
        shared_organizations: [],
        shared_case_count: 1,
        text_fragments: [ "The collaboration was backed by sustained support and funding." ]
      },
      "sharpening" => {
        shared_tags: [],
        shared_organizations: [],
        shared_case_count: 1,
        text_fragments: [ "Their rivalry and critique sharpened the field." ]
      }
    }

    samples.each do |kind, facts|
      classification = RelationshipKindClassifier.classify(**facts)

      assert_equal kind, classification[:kind]
      assert_equal RelationshipKindClassifier.label_for(kind), classification[:kind_label]
      assert classification[:reason].present?
    end
  end
end
