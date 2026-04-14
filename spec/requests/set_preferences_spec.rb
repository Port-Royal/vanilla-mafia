require "rails_helper"

RSpec.describe "SetPreferences concern", type: :request do
  before do
    Rails.application.routes.draw do
      get "/_test_preferences" => "preferences_probe#show"
    end
  end

  after { Rails.application.reload_routes! }

  # An ephemeral controller that echoes Current values into the response body
  # so the test can inspect what SetPreferences produced during the request.
  before do
    stub_const("PreferencesProbeController", Class.new(ApplicationController) do
      def show
        render plain: "#{Current.datetime_format}|#{Current.time_zone}|#{Time.zone.name}|#{I18n.locale}"
      end
    end)
  end

  def probe
    get "/_test_preferences"
    response.body.split("|")
  end

  describe "datetime_format resolution" do
    context "when signed in" do
      let(:user) { create(:user, datetime_format: "iso") }

      before { sign_in user }

      it "prefers user record over cookie" do
        cookies[:datetime_format] = "us_12h"
        fmt, = probe

        expect(fmt).to eq("iso")
      end
    end

    context "when guest" do
      it "uses cookie value when valid" do
        cookies[:datetime_format] = "iso"
        fmt, = probe

        expect(fmt).to eq("iso")
      end

      it "falls back to european_24h when cookie missing" do
        fmt, = probe

        expect(fmt).to eq("european_24h")
      end

      it "falls back to european_24h when cookie invalid" do
        cookies[:datetime_format] = "bogus"
        fmt, = probe

        expect(fmt).to eq("european_24h")
      end
    end
  end

  describe "time_zone resolution" do
    it "uses tz cookie when valid" do
      cookies[:tz] = "Europe/Moscow"
      _, tz, time_zone_name = probe

      expect(tz).to eq("Europe/Moscow")
      expect(time_zone_name).to eq("Europe/Moscow")
    end

    it "falls back to UTC when cookie missing" do
      _, tz, time_zone_name = probe

      expect(tz).to eq("UTC")
      expect(time_zone_name).to eq("UTC")
    end

    it "falls back to UTC when cookie is an unknown zone" do
      cookies[:tz] = "Not/AZone"
      _, tz, time_zone_name = probe

      expect(tz).to eq("UTC")
      expect(time_zone_name).to eq("UTC")
    end

    it "falls back to UTC when cookie is blank" do
      cookies[:tz] = ""
      _, tz, time_zone_name = probe

      expect(tz).to eq("UTC")
      expect(time_zone_name).to eq("UTC")
    end
  end

  describe "locale resolution (preserved from SetLocale)" do
    it "uses cookie when valid" do
      cookies[:locale] = "en"
      _, _, _, locale = probe

      expect(locale).to eq("en")
    end

    it "falls back to default when cookie missing" do
      _, _, _, locale = probe

      expect(locale).to eq("ru")
    end
  end
end
