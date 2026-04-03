ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'securerandom'

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

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

class ActionDispatch::IntegrationTest
  DEFAULT_PASSWORD = 'password123'.freeze

  def create_user(role: 'editor', status: 'active', email: nil, password: DEFAULT_PASSWORD)
    User.create!(
      email: email || "#{role}-#{SecureRandom.hex(6)}@example.com",
      password: password,
      password_confirmation: password,
      role: role,
      status: status
    )
  end

  def sign_in_as(user, password: DEFAULT_PASSWORD)
    post login_path, params: { email: user.email, password: password }
    assert_response :redirect
  end
end
