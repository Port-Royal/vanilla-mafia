require "rails_helper"

RSpec.describe "Content-Security-Policy header" do
  it "ships in report-only mode (no enforcing header)" do
    get root_path

    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_present
    expect(response.headers["Content-Security-Policy"]).to be_blank
  end

  describe "report-only directives" do
    let(:csp) { response.headers["Content-Security-Policy-Report-Only"] }

    before { get root_path }

    it "restricts default-src to self" do
      expect(csp).to include("default-src 'self'")
    end

    it "denies object-src" do
      expect(csp).to include("object-src 'none'")
    end

    it "denies frame-ancestors (clickjacking)" do
      expect(csp).to include("frame-ancestors 'none'")
    end

    it "restricts base-uri to self" do
      expect(csp).to include("base-uri 'self'")
    end

    it "allows form posts to self and Google accounts (omniauth)" do
      expect(csp).to include("form-action 'self' https://accounts.google.com")
    end

    it "restricts script-src to self + https with a nonce" do
      expect(csp).to match(/script-src 'self' https: 'nonce-[A-Za-z0-9+\/=_-]+'/)
    end

    it "permits style-src self + https + unsafe-inline (Avo)" do
      expect(csp).to include("style-src 'self' https: 'unsafe-inline'")
    end

    it "permits img-src self + https + data" do
      expect(csp).to include("img-src 'self' https: data:")
    end

    it "permits font-src self + https + data" do
      expect(csp).to include("font-src 'self' https: data:")
    end

    it "permits connect-src self + https" do
      expect(csp).to include("connect-src 'self' https:")
    end

    it "configures report-uri to the CSP violation endpoint" do
      expect(csp).to include("report-uri /csp_violation_reports")
    end
  end

  describe "rendered page" do
    it "stamps the script-src nonce onto inline <script> tags" do
      get root_path

      csp = response.headers["Content-Security-Policy-Report-Only"]
      nonce_match = csp.match(/script-src[^;]*'nonce-([A-Za-z0-9+\/=_-]+)'/)
      expect(nonce_match).to be_present, "expected script-src nonce in CSP header, got: #{csp}"

      nonce = nonce_match[1]
      expect(response.body).to match(/<script\b[^>]*\bnonce="#{Regexp.escape(nonce)}"/)
    end
  end
end
