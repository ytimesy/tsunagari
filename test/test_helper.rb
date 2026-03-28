ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def with_stubbed_method(object, method_name, return_value = nil, callable: nil)
      singleton = class << object; self; end
      method_defined = singleton.method_defined?(method_name) || singleton.private_method_defined?(method_name)
      backup_name = "__codex_original_#{method_name}_#{object.object_id}".to_sym

      singleton.send(:alias_method, backup_name, method_name) if method_defined

      singleton.send(:define_method, method_name) do |*args, **kwargs, &block|
        if callable
          callable.call(*args, **kwargs, &block)
        else
          return_value
        end
      end

      yield
    ensure
      singleton.send(:remove_method, method_name)
      if method_defined
        singleton.send(:alias_method, method_name, backup_name)
        singleton.send(:remove_method, backup_name)
      end
    end
  end
end
