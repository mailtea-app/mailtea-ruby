# frozen_string_literal: true

require "openssl"

# Standard Webhooks (standardwebhooks.com) signature verification.
#
# A stdlib-only mirror of the Mailtea signer, kept in exact parity so a signature
# produced by the platform verifies here byte-for-byte.
#
# The stored signing secret is <tt>whsec_<base64></tt>; the HMAC key is the
# base64 remainder decoded to bytes. The signed content is
# <tt>{msg_id}.{timestamp}.{payload}</tt> where +timestamp+ is Unix SECONDS,
# matching the +webhook-timestamp+ header. The +webhook-signature+ header is
# <tt>v1,<base64 HMAC-SHA256></tt>; during key rotation it may carry several
# space-delimited <tt>v1,<sig></tt> tokens and a match against any one of them
# passes.
module Mailtea
  SECRET_PREFIX = "whsec_"
  SIGNATURE_VERSION = "v1"
  DEFAULT_TOLERANCE_SECONDS = 300

  module_function

  # Sign a webhook payload.
  #
  # Returns the +webhook-signature+ header value in Standard Webhooks form,
  # <tt>v1,<base64 HMAC-SHA256></tt>. Useful for faking Mailtea deliveries in
  # tests.
  #
  # +timestamp+ is Unix seconds — the same value sent in +webhook-timestamp+.
  def sign_webhook(secret, msg_id, timestamp, payload)
    "#{SIGNATURE_VERSION},#{compute_signature(secret, msg_id, timestamp.to_i, payload)}"
  end

  # Verify a +webhook-signature+ header against the expected HMAC.
  #
  # The header may carry multiple space-delimited <tt>v1,<sig></tt> tokens
  # (Standard Webhooks allows key rotation — the platform may sign a delivery
  # with both the old and new secret); a match against any +v1+ token passes.
  #
  # Returns false when the timestamp is outside +tolerance_seconds+ of +now+
  # (replay protection). Uses a constant-time comparison. Never raises on a bad
  # signature — it returns false.
  #
  # [secret]           the endpoint's signing secret (+whsec_...+).
  # [msg_id]           the +webhook-id+ header value.
  # [timestamp]        the +webhook-timestamp+ header value (Unix seconds; the
  #                    String the header arrives as is accepted and coerced).
  # [payload]          the raw request body, exactly as received.
  # [signature_header] the +webhook-signature+ header value.
  # [tolerance_seconds] allowed clock skew each way. Default 5 minutes.
  # [now]              injectable current time (Unix seconds) for tests.
  #
  #   ok = Mailtea.verify_webhook_signature(
  #     signing_secret,
  #     request.headers["webhook-id"],
  #     request.headers["webhook-timestamp"],
  #     request.raw_post,
  #     request.headers["webhook-signature"]
  #   )
  def verify_webhook_signature(secret, msg_id, timestamp, payload, signature_header,
                               tolerance_seconds: DEFAULT_TOLERANCE_SECONDS, now: nil)
    timestamp_seconds = coerce_timestamp(timestamp)
    return false if timestamp_seconds.nil?

    now_seconds = (now.nil? ? Time.now.to_i : now.to_i)
    return false if (now_seconds - timestamp_seconds).abs > tolerance_seconds

    expected = compute_signature(secret, msg_id, timestamp_seconds, payload)

    signature_header.to_s.split(" ").any? do |token|
      version, _, signature = token.partition(",")
      # OpenSSL's comparison is length-safe and constant-time; == on Strings is
      # neither, and a byte-by-byte early exit is a timing oracle on the digest.
      version == SIGNATURE_VERSION &&
        !signature.empty? &&
        OpenSSL.secure_compare(signature, expected)
    end
  end

  # Decode the HMAC key from a +whsec_+-prefixed secret.
  #
  # Matches Node's lenient base64 decoder: accepts the base64url alphabet and
  # tolerates missing padding, so a secret minted with either alphabet decodes to
  # the same bytes.
  def decode_signing_key(secret)
    raw = secret.start_with?(SECRET_PREFIX) ? secret[SECRET_PREFIX.length..] : secret
    raw = raw.strip.tr("-_", "+/")
    raw += "=" * ((4 - (raw.length % 4)) % 4)
    raw.unpack1("m")
  end

  def compute_signature(secret, msg_id, timestamp, payload)
    signed_content = "#{msg_id}.#{timestamp}.#{payload}"
    digest = OpenSSL::HMAC.digest("SHA256", decode_signing_key(secret), signed_content)
    [digest].pack("m0")
  end

  # A header value is a String, and String#to_i turns "abc" into 0 — which would
  # be inside no tolerance window but is still a value, so the parse has to fail
  # loudly rather than round to the epoch.
  def coerce_timestamp(timestamp)
    return timestamp.floor if timestamp.is_a?(Integer)
    return nil if timestamp.is_a?(Float) && !timestamp.finite?
    return timestamp.floor if timestamp.is_a?(Numeric)

    Float(timestamp.to_s).floor
  rescue ArgumentError, TypeError, FloatDomainError
    nil
  end

  private_class_method :decode_signing_key, :compute_signature, :coerce_timestamp
end
