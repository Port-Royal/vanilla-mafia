require "rails_helper"

RSpec.describe PermissionsPolicyHeader do
  let(:downstream_status) { 200 }
  let(:downstream_headers) { {} }
  let(:downstream_body) { [ "ok" ] }
  let(:downstream_response) { [ downstream_status, downstream_headers, downstream_body ] }
  let(:app) { ->(_env) { downstream_response } }
  let(:middleware) { described_class.new(app) }

  describe "#call" do
    it "returns the downstream status unchanged" do
      status, _, _ = middleware.call({})
      expect(status).to eq(200)
    end

    it "returns the downstream body unchanged" do
      _, _, body = middleware.call({})
      expect(body).to eq([ "ok" ])
    end

    it "sets the Permissions-Policy header" do
      _, headers, _ = middleware.call({})
      expect(headers["Permissions-Policy"]).to eq(described_class::HEADER_VALUE)
    end

    it "does not overwrite a pre-existing Permissions-Policy header" do
      downstream_headers["Permissions-Policy"] = "camera=(self)"
      _, headers, _ = middleware.call({})
      expect(headers["Permissions-Policy"]).to eq("camera=(self)")
    end

    it "passes the rack env unchanged to the downstream app" do
      captured_env = nil
      capturing_app = ->(env) { captured_env = env; downstream_response }
      middleware = described_class.new(capturing_app)

      input_env = { "PATH_INFO" => "/foo" }
      middleware.call(input_env)

      expect(captured_env).to equal(input_env)
    end
  end

  describe "HEADER_VALUE" do
    it "disables camera access" do
      expect(described_class::HEADER_VALUE).to include("camera=()")
    end

    it "disables microphone access" do
      expect(described_class::HEADER_VALUE).to include("microphone=()")
    end

    it "disables geolocation access" do
      expect(described_class::HEADER_VALUE).to include("geolocation=()")
    end

    it "disables gyroscope access" do
      expect(described_class::HEADER_VALUE).to include("gyroscope=()")
    end

    it "disables USB access" do
      expect(described_class::HEADER_VALUE).to include("usb=()")
    end

    it "disables payment access" do
      expect(described_class::HEADER_VALUE).to include("payment=()")
    end

    it "restricts fullscreen to same origin" do
      expect(described_class::HEADER_VALUE).to include("fullscreen=(self)")
    end

    it "is frozen" do
      expect(described_class::HEADER_VALUE).to be_frozen
    end
  end
end
