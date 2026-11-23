require "rails_helper"

RSpec.describe "Error pages" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:page) { document.at_css("main#site-main #error-page") }
  let(:code) { page.at_css("[data-error-code]") }
  let(:title) { page.at_css("h1") }
  let(:message) { page.at_css("[data-error-message]") }
  let(:home_link) { page.at_css("a.vm-btn--primary") }
  let(:path) { "/404" }
  let(:signed_in_user) { nil }

  around do |example|
    env = Rails.application.env_config
    original_show = env["action_dispatch.show_exceptions"]
    original_local = env["action_dispatch.show_detailed_exceptions"]
    env["action_dispatch.show_exceptions"] = :all
    env["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env["action_dispatch.show_exceptions"] = original_show
    env["action_dispatch.show_detailed_exceptions"] = original_local
  end

  before do
    sign_in signed_in_user if signed_in_user
    get path
  end

  shared_examples "the error page" do |status, error_code|
    it { expect(response).to have_http_status(status) }
    it { expect(code.text.strip).to eq(error_code) }
    it { expect(code["aria-hidden"]).to eq("true") }
    it { expect(title.text.strip).to eq(I18n.t("errors.#{error_code}.title")) }
    it { expect(title["class"]).to include("font-serif") }
    it { expect(page["aria-labelledby"]).to eq(title["id"]) }
    it { expect(message.text.strip).to eq(I18n.t("errors.#{error_code}.message")) }
    it { expect(home_link.text.strip).to eq(I18n.t("errors.back_home")) }
    it { expect(home_link["href"]).to eq("/") }
    it { expect(document.at_css('meta[name="robots"]')["content"]).to eq("noindex, nofollow") }
    it { expect(document.at_css("head title").text).to eq("#{I18n.t("errors.#{error_code}.title")} — Vanilla Mafia") }
  end

  context "with GET /404" do
    it_behaves_like "the error page", :not_found, "404"
  end

  context "with GET /422" do
    let(:path) { "/422" }

    it_behaves_like "the error page", :unprocessable_content, "422"
  end

  context "with GET /500" do
    let(:path) { "/500" }

    it_behaves_like "the error page", :internal_server_error, "500"
  end

  context "with a code in the query string" do
    let(:path) { "/404?code=200" }

    it_behaves_like "the error page", :not_found, "404"
  end

  context "with a missing page" do
    let(:path) { "/nonexistent-path" }

    it_behaves_like "the error page", :not_found, "404"
  end

  context "with a missing record" do
    let(:path) { "/players/missing-player" }

    it_behaves_like "the error page", :not_found, "404"
  end

  context "when an admin is signed in" do
    let_it_be(:admin) { create(:user, :admin) }
    let(:signed_in_user) { admin }

    it_behaves_like "the error page", :not_found, "404"
  end
end
