require "rails_helper"

RSpec.describe "Security headers" do
  describe "Permissions-Policy" do
    it "sets a restrictive Permissions-Policy header on responses" do
      get root_path

      header = response.headers["Permissions-Policy"]
      expect(header).to be_present
    end

    it "disables camera, microphone, geolocation, and payment" do
      get root_path

      header = response.headers["Permissions-Policy"]
      expect(header).to include("camera=()")
      expect(header).to include("microphone=()")
      expect(header).to include("geolocation=()")
      expect(header).to include("payment=()")
    end

    it "restricts fullscreen to same origin" do
      get root_path

      expect(response.headers["Permissions-Policy"]).to include("fullscreen=(self)")
    end
  end
end
