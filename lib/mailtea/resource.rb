# frozen_string_literal: true

require_relative "error"
require_relative "util"

module Mailtea
  # Base class for the resource objects hanging off Mailtea::Client. It holds
  # the client's request callable; everything else lives in the subclasses.
  class Resource
    def initialize(request)
      @request = request
    end

    private

    # +raw+ hands back the response body as text instead of parsed JSON, for the
    # handful of endpoints that answer with something other than JSON.
    def request(method, path, body = nil, raw: false)
      @request.call(method, path, body, raw: raw)
    end

    def payload(*sources)
      Util.payload(*sources)
    end

    def query(params)
      Util.query(params)
    end

    def escape(value)
      Util.escape(value)
    end
  end
end
