# frozen_string_literal: true

require "minitest/autorun"

require "mailtea"
require_relative "mock_mailtea"

# Base class for the resource tests: a client pointed at the bundled mock API.
# Nothing here touches the network or reads a credential.
class MailteaTest < Minitest::Test
  API_KEY = "mt_pat_test"

  def setup
    @mock = MockMailtea.new
    @mailtea = Mailtea::Client.new(API_KEY, base_url: @mock.url)
  end

  def teardown
    @mock.close
  end

  private

  # Assert the last request's verb and path, and that it carried the key.
  def assert_request(method, pathname, message = nil)
    request = @mock.last
    refute_nil request, "no request was made"
    assert_equal "#{method} #{pathname}", request.route, message
    assert_equal "Bearer #{API_KEY}", request.authorization
    request
  end

  def last_body
    @mock.last.body
  end

  def last_query
    @mock.last.query
  end
end
