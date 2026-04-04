require "test_helper"

class RepresentativeFieldCatalogTest < ActiveSupport::TestCase
  test "provides 100 representative fields across 10 groups" do
    assert_equal 10, RepresentativeFieldCatalog.groups.count
    assert_equal 100, RepresentativeFieldCatalog.count
    assert_includes RepresentativeFieldCatalog.field_names, "AI"
    assert_includes RepresentativeFieldCatalog.field_names, "政治"
    assert_includes RepresentativeFieldCatalog.field_names, "YouTube"
  end

  test "sync_tags creates the catalog tags idempotently" do
    assert_difference -> { Tag.count }, 100 do
      RepresentativeFieldCatalog.sync_tags!
    end

    assert_no_difference -> { Tag.count } do
      RepresentativeFieldCatalog.sync_tags!
    end

    assert_equal 100, Tag.where(normalized_name: RepresentativeFieldCatalog.field_names.map(&:downcase)).count
  end
end
