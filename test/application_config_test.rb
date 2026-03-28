require "test_helper"

class ApplicationConfigTest < ActiveSupport::TestCase
  test "autoloads service objects from app/services" do
    services_path = Rails.root.join("app/services").to_s

    autoload_paths = Rails.application.config.autoload_paths.map(&:to_s)
    eager_load_paths = Rails.application.config.eager_load_paths.map(&:to_s)

    assert_includes autoload_paths, services_path
    assert_includes eager_load_paths, services_path
  end
end
