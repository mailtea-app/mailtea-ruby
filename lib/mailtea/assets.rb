# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +assets+ resource (a publication's image library). Reach it at
  # <tt>mailtea.assets</tt>.
  #
  # An email or site image needs an absolute URL, so this is how a picture that
  # is not already in the library gets into one. Pointing an image at a host you
  # do not control breaks the day that host moves the file.
  #
  # PNG, JPEG, GIF, WebP or SVG, 5 MB per image. The bytes are checked against
  # the declared +content_type+, so a mislabelled file is rejected rather than
  # stored. SVG is served with <tt>Content-Security-Policy: sandbox</tt>, which
  # is what makes hosting one from the publication's own domain safe.
  #
  #   asset = mailtea.assets.upload(
  #     publication_id: "pub_123",
  #     content: File.binread("hero.png"),   # base64-encoded for you
  #     content_type: "image/png",
  #     filename: "hero.png"
  #   )
  #   asset["url"]  # -> use as an image block's src
  class Assets < Resource
    # Upload an image. Takes +publication_id+, +content+, +content_type+ and
    # +filename+.
    #
    # +content+ takes raw bytes — read the file with File.binread — and is
    # base64-encoded for you, or a String you already encoded, which is sent
    # untouched.
    def upload(params = nil, **fields)
      body = payload(params, fields)
      content = body["content"]
      body["content"] = [content].pack("m0") if content.is_a?(String) && raw_bytes?(content)
      request("POST", "/v1/assets", body)
    end

    # List the library, newest first. Filters: +publication_id+ (required),
    # +search+ (file name), +limit+ (1-200, default 100).
    def list(params = nil, **filters)
      request("GET", "/v1/assets" + query(payload(params, filters)))
    end

    # Retire an asset.
    #
    # The stored file is KEPT and its URL keeps resolving, so images inside
    # already-sent emails do not break. This hides the asset from the library —
    # it does not remove it from any email, template or page referencing it.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/assets/" + escape(id) + query(payload(params, filters)))
    end

    private

    # Ruby has no separate bytes type, so image bytes and an already-encoded
    # string are both Strings, and the encoding is what tells them apart:
    # File.binread returns ASCII-8BIT, a base64 string is ordinary text.
    #
    # This reads the label rather than sniffing the contents. Sniffing cannot
    # settle it — an SVG read as text is valid UTF-8 and is not base64, so any
    # rule loose enough to catch it also catches short base64 and encodes it
    # twice, uploading gibberish of exactly the right content type. Reading
    # image files with File.binread keeps both cases unambiguous.
    def raw_bytes?(content)
      content.encoding == Encoding::BINARY || !content.valid_encoding?
    end
  end
end
