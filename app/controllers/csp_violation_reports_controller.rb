class CspViolationReportsController < ActionController::API
  CSP_REPORT_TYPE = "application/csp-report"
  REPORTS_API_TYPE = "application/reports+json"
  ACCEPTED_TYPES = [ CSP_REPORT_TYPE, REPORTS_API_TYPE ].freeze

  # Violations injected by browser extensions (script-src eval, injected scripts) are noise,
  # not caused by our site. Skip them so Sentry only sees violations we can act on.
  EXTENSION_SCHEMES = %w[chrome-extension moz-extension safari-extension safari-web-extension edge-extension webkit-masked-url].freeze

  def create
    return head(:unsupported_media_type) unless ACCEPTED_TYPES.include?(request.media_type)

    parse_and_forward
    head :no_content
  end

  private

  def parse_and_forward
    payload = JSON.parse(request.raw_post)

    case request.media_type
    when CSP_REPORT_TYPE
      forward_single(payload["csp-report"])
    when REPORTS_API_TYPE
      Array(payload).each { |entry| forward_reports_api(entry) }
    end
  rescue JSON::ParserError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    # Public endpoint — browsers occasionally send malformed or badly-encoded payloads; never 5xx on arbitrary input.
    nil
  end

  def forward_single(report)
    return if report.blank?
    return if browser_extension_noise?(report["source-file"], report["blocked-uri"])

    directive = report["effective-directive"].presence || report["violated-directive"].presence || "unknown"
    Sentry.capture_message("CSP violation: #{directive}", level: :warning, extra: report)
  end

  def forward_reports_api(entry)
    return unless entry.is_a?(Hash) && entry["type"] == "csp-violation"

    body = entry["body"].to_h
    return if browser_extension_noise?(body["sourceFile"], body["blockedURL"])

    directive = body["effectiveDirective"].presence || body["violatedDirective"].presence || "unknown"
    Sentry.capture_message("CSP violation: #{directive}", level: :warning, extra: body)
  end

  def browser_extension_noise?(*fields)
    fields.any? do |value|
      scheme = value.to_s.split("://").first
      EXTENSION_SCHEMES.include?(scheme)
    end
  end
end
