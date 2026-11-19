require "rails_helper"

RSpec.describe NavigationHelper, type: :helper do
  describe "#nav_active?" do
    let(:request_method) { "GET" }
    let(:query_string) { "" }

    before do
      controller.request.path = current_path
      controller.request.query_string = query_string
      controller.request.request_method = request_method
    end

    context "when on the Hall of Fame page" do
      let(:current_path) { hall_path }

      it { expect(helper.nav_active?(hall_path)).to be(true) }
      it { expect(helper.nav_active?(news_index_path)).to be(false) }

      context "with a query string" do
        let(:query_string) { "x=1" }

        it { expect(helper.nav_active?(hall_path)).to be(true) }
      end
    end

    context "when on the news index" do
      let(:current_path) { news_index_path }

      it { expect(helper.nav_active?(news_index_path)).to be(true) }
    end

    context "when on the news index with a trailing slash" do
      let(:current_path) { "#{news_index_path}/" }

      it { expect(helper.nav_active?(news_index_path)).to be(true) }
    end

    context "when on a news article" do
      let(:current_path) { "#{news_index_path}/some-slug" }

      it { expect(helper.nav_active?(news_index_path)).to be(true) }
      it { expect(helper.nav_active?(hall_path)).to be(false) }

      context "with a HEAD request" do
        let(:request_method) { "HEAD" }

        it { expect(helper.nav_active?(news_index_path)).to be(true) }
      end

      context "with a non-GET request" do
        let(:request_method) { "POST" }

        it { expect(helper.nav_active?(news_index_path)).to be(false) }
      end
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
