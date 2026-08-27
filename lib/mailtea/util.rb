# frozen_string_literal: true

require "uri"

module Mailtea
  # Sentinel for "this keyword was not given".
  #
  # It exists because +nil+ already means something on the wire: the API clears a
  # nullable field when it receives an explicit JSON +null+, and leaves it alone
  # when the key is absent. A keyword defaulting to +nil+ would collapse those
  # two, so every optional keyword defaults to UNSET and is dropped from the
  # payload; pass +nil+ deliberately and it is sent as +null+.
  #
  #   mailtea.segments.update(id, publication_id: pub)                     # leaves the filter alone
  #   mailtea.segments.update(id, publication_id: pub, status_filter: nil) # clears it
  UNSET = Object.new
  def UNSET.inspect
    "Mailtea::UNSET"
  end
  UNSET.freeze

  # Internal helpers shared by the resource classes. Not part of the public API.
  module Util
    module_function

    # Merge a wire-format Hash with keyword arguments into one payload.
    #
    # Sources are applied left to right, so keywords win over the Hash — the same
    # precedence the Python SDK uses. Keys are stringified, so
    # <tt>send({"from" => a}, from: b)</tt> is one key, not two.
    def payload(*sources)
      merged = {}
      sources.each do |source|
        next if source.nil?

        source.each do |key, value|
          next if value.equal?(UNSET)

          merged[key.to_s] = value
        end
      end
      merged
    end

    # Render "?a=1&b=2" from a Hash, dropping nil and UNSET values.
    #
    # Returns "" for an empty result so it can be appended to a path
    # unconditionally. Array values become repeated keys (+a=1&a=2+); booleans
    # render as +true+/+false+, which is what the API's query parsers read.
    def query(params)
      return "" if params.nil? || params.empty?

      pairs = params.each_with_object([]) do |(key, value), acc|
        next if value.nil? || value.equal?(UNSET)

        acc << [key.to_s, value]
      end
      pairs.empty? ? "" : "?#{URI.encode_www_form(pairs)}"
    end

    # Percent-encode one path segment. Every reserved character is escaped
    # (including "/"), so an id containing a slash cannot walk to another route.
    def escape(value)
      value.to_s.gsub(/[^A-Za-z0-9\-._~]/) do |char|
        char.bytes.map { |byte| format("%%%02X", byte) }.join
      end
    end

    # Split a payload into the publication_id that several endpoints want in the
    # query string and the rest of the body. Returns [query_string, body].
    def split_publication(merged, keep_in_body: true)
      publication_id = merged["publication_id"]
      body = keep_in_body ? merged : merged.reject { |key, _| key == "publication_id" }
      [query({ "publication_id" => publication_id }), body]
    end
  end
end
