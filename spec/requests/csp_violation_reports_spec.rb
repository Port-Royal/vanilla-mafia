require "rails_helper"

RSpec.describe CspViolationReportsController, type: :request do
  let(:csp_report_payload) do
    {
      "csp-report" => {
        "document-uri" => "https://example.com/",
        "referrer" => "",
        "violated-directive" => "script-src-elem",
        "effective-directive" => "script-src-elem",
        "original-policy" => "default-src 'self'; report-uri /csp_violation_reports",
        "disposition" => "report",
        "blocked-uri" => "https://evil.example.com/xss.js",
        "status-code" => 200,
        "script-sample" => ""
      }
    }
  end

  let(:reports_api_payload) do
    [
      {
        "age" => 10,
        "body" => {
          "blockedURL" => "https://evil.example.com/xss.js",
          "disposition" => "report",
          "documentURL" => "https://example.com/",
          "effectiveDirective" => "script-src-elem",
          "originalPolicy" => "default-src 'self'; report-to csp-endpoint",
          "referrer" => "",
          "statusCode" => 200
        },
        "type" => "csp-violation",
        "url" => "https://example.com/",
        "user_agent" => "Mozilla/5.0"
      }
    ]
  end

  describe "POST /csp_violation_reports" do
    context "with application/csp-report body" do
      it "returns 204 No Content" do
        post csp_violation_reports_path,
             params: csp_report_payload.to_json,
             headers: { "CONTENT_TYPE" => "application/csp-report" }

        expect(response).to have_http_status(:no_content)
      end

      it "forwards the violation to Sentry" do
        expect(Sentry).to receive(:capture_message).with(
          "CSP violation: script-src-elem",
          hash_including(level: :warning, extra: hash_including("blocked-uri" => "https://evil.example.com/xss.js"))
        )

        post csp_violation_reports_path,
             params: csp_report_payload.to_json,
             headers: { "CONTENT_TYPE" => "application/csp-report" }
      end

      it "accepts content type with parameters (charset)" do
        post csp_violation_reports_path,
             params: csp_report_payload.to_json,
             headers: { "CONTENT_TYPE" => "application/csp-report; charset=utf-8" }

        expect(response).to have_http_status(:no_content)
      end

      context "when effective-directive and violated-directive are both missing" do
        let(:csp_report_payload) do
          { "csp-report" => { "document-uri" => "https://example.com/", "blocked-uri" => "inline" } }
        end

        it "falls back to 'unknown' in the Sentry title" do
          expect(Sentry).to receive(:capture_message).with("CSP violation: unknown", anything)

          post csp_violation_reports_path,
               params: csp_report_payload.to_json,
               headers: { "CONTENT_TYPE" => "application/csp-report" }
        end
      end
    end

    context "with application/reports+json body" do
      it "returns 204 No Content" do
        post csp_violation_reports_path,
             params: reports_api_payload.to_json,
             headers: { "CONTENT_TYPE" => "application/reports+json" }

        expect(response).to have_http_status(:no_content)
      end

      it "forwards each csp-violation report to Sentry" do
        expect(Sentry).to receive(:capture_message).with(
          "CSP violation: script-src-elem",
          hash_including(level: :warning, extra: hash_including("blockedURL" => "https://evil.example.com/xss.js"))
        )

        post csp_violation_reports_path,
             params: reports_api_payload.to_json,
             headers: { "CONTENT_TYPE" => "application/reports+json" }
      end

      it "ignores non-csp-violation report types" do
        payload = [ { "type" => "deprecation", "body" => { "id" => "old-api" } } ]
        expect(Sentry).not_to receive(:capture_message)

        post csp_violation_reports_path,
             params: payload.to_json,
             headers: { "CONTENT_TYPE" => "application/reports+json" }

        expect(response).to have_http_status(:no_content)
      end
    end

    context "with malformed JSON body" do
      it "returns 204 without raising" do
        expect(Sentry).not_to receive(:capture_message)

        post csp_violation_reports_path,
             params: "not json{",
             headers: { "CONTENT_TYPE" => "application/csp-report" }

        expect(response).to have_http_status(:no_content)
      end
    end

    context "with invalid byte sequence in body" do
      it "returns 204 without raising" do
        expect(Sentry).not_to receive(:capture_message)

        post csp_violation_reports_path,
             params: "\xFF\xFE".b,
             headers: { "CONTENT_TYPE" => "application/csp-report" }

        expect(response).to have_http_status(:no_content)
      end
    end

    context "with unsupported content type" do
      it "returns 415 Unsupported Media Type" do
        post csp_violation_reports_path,
             params: "{}",
             headers: { "CONTENT_TYPE" => "text/plain" }

        expect(response).to have_http_status(:unsupported_media_type)
      end
    end

    context "without CSRF token" do
      it "does not raise an InvalidAuthenticityToken error" do
        expect {
          post csp_violation_reports_path,
               params: csp_report_payload.to_json,
               headers: { "CONTENT_TYPE" => "application/csp-report" }
        }.not_to raise_error
      end
    end
  end
end
