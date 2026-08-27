# frozen_string_literal: true

module Mailtea
  # An API response: the parsed JSON, as a Hash that accepts Symbol keys too.
  #
  #   email["id"]   # => "txemail_..."
  #   email[:id]    # => "txemail_..."
  #
  # Keys are the wire names exactly as the API sends them (snake_case strings) —
  # nothing is renamed on the way in, so what the API reference documents is what
  # you index. Symbol access exists because a Ruby caller writing +email[:id]+
  # right after writing +send(to:, subject:)+ should not get +nil+.
  #
  # +[]+, +[]=+, +fetch+, +key?+, +dig+ and +delete+ all normalize. Hash's bulk
  # mutators (+merge+, +merge!+, +update+) are C-implemented and do not route
  # through +[]=+, so a Symbol key added that way stays a Symbol — merge into a
  # plain Hash if you need that, rather than into a response.
  class Response < Hash
    def [](key)
      super(normalize(key))
    end

    def fetch(key, *args, &block)
      super(normalize(key), *args, &block)
    end

    def key?(key)
      super(normalize(key))
    end
    alias has_key? key?
    alias include? key?
    alias member? key?

    # Writes normalize too, or the class keeps only half its promise: a caller
    # who sets email[:status] and reads email[:status] back would get nil,
    # because the read side went looking for "status". (The JSON parser builds
    # these through []= with String keys, where normalize is a no-op.)
    def []=(key, value)
      super(normalize(key), value)
    end
    alias store []=

    def delete(key, &block)
      super(normalize(key), &block)
    end

    # Hash#dig is C-implemented and would not route through the [] above, so a
    # nested lookup with symbols needs its own walk.
    def dig(key, *rest)
      value = self[key]
      return value if rest.empty? || value.nil?

      value.dig(*rest)
    end

    private

    def normalize(key)
      key.is_a?(Symbol) ? key.to_s : key
    end
  end
end
