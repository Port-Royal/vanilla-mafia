require "rails_helper"

RSpec.describe NavigationHelper, type: :helper do
  describe "#nav_active?" do
    before { controller.request.path = current_path }

    context "when on the Hall of Fame page" do
      let(:current_path) { hall_path }

      it { expect(helper.nav_active?(hall_path)).to be(true) }
      it { expect(helper.nav_active?(news_index_path)).to be(false) }
    end

    context "when on the news index" do
      let(:current_path) { news_index_path }

      it { expect(helper.nav_active?(news_index_path)).to be(true) }
    end

    context "when on a news article" do
      let(:current_path) { "#{news_index_path}/some-slug" }

      it { expect(helper.nav_active?(news_index_path)).to be(true) }
      it { expect(helper.nav_active?(hall_path)).to be(false) }
    end

    context "when on a path that only starts with the news path" do
      let(:current_path) { "/newsletter" }

      it { expect(helper.nav_active?(news_index_path)).to be(false) }
    end

    context "when on a page below the Hall of Fame path" do
      let(:current_path) { "#{hall_path}/some-player" }

      it { expect(helper.nav_active?(hall_path)).to be(false) }
    end
  end
end
