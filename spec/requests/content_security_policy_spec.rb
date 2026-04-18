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

    it "issues a per-request nonce on script-src" do
      expect(csp).to match(/script-src[^;]*'nonce-[A-Za-z0-9+\/=_-]+'/)
    end
  end
end
