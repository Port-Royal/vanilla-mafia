require "rails_helper"

RSpec.describe "Footer" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:footer) { document.at_css("footer#site-footer") }

  before { get hall_path }

  it "follows the main content" do
    expect(document.at_css("main#site-main ~ footer#site-footer")).to be_present
  end

  it "shows the copyright with the current year" do
    expect(footer.text).to include(I18n.t("footer.copyright", year: Date.current.year))
  end

  it { expect(footer.at_css("a[href='#{hall_path}']").text).to eq(I18n.t("nav.hall_of_fame")) }
  it { expect(footer.at_css("a[href='#{news_index_path}']").text).to eq(I18n.t("nav.news")) }
  it { expect(footer.at_css("a[href='#{stats_path}']").text).to eq(I18n.t("nav.stats")) }
  it { expect(footer.css("nav a").map { |link| link["class"].split }).to all(include("min-h-11")) }
  it { expect(footer.css("form")).to be_empty }
end
