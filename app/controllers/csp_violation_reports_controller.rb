class CspViolationReportsController < ActionController::API
  CSP_REPORT_TYPE = "application/csp-report"
  REPORTS_API_TYPE = "application/reports+json"
  ACCEPTED_TYPES = [ CSP_REPORT_TYPE, REPORTS_API_TYPE ].freeze

  def create
    return head(:unsupported_media_type) unless ACCEPTED_TYPES.include?(request.content_type)

    parse_and_forward
    head :no_content
  end

  private

  def parse_and_forward
    payload = JSON.parse(request.raw_post)

    case request.content_type
    when CSP_REPORT_TYPE
      forward_single(payload["csp-report"])
    when REPORTS_API_TYPE
      Array(payload).each { |entry| forward_reports_api(entry) }
    end
  rescue JSON::ParserError
    # Browsers occasionally send malformed payloads — swallow so we never 5xx on arbitrary public input.
    nil
  end

  def forward_single(report)
    return if report.blank?

    directive = report["effective-directive"].presence || report["violated-directive"]
    Sentry.capture_message("CSP violation: #{directive}", level: :warning, extra: report)
  end

  def forward_reports_api(entry)
    return unless entry.is_a?(Hash) && entry["type"] == "csp-violation"

    body = entry["body"].to_h
    directive = body["effectiveDirective"].presence || body["violatedDirective"]
    Sentry.capture_message("CSP violation: #{directive}", level: :warning, extra: body)
  end
end
