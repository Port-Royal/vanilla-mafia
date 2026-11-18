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

  describe NavigationHelper::NavItem do
    subject(:item) { described_class.new(:help, "Help", "/help") }

    it "takes key, label and path in that order" do
      expect(item.to_h).to eq(key: :help, label: "Help", path: "/help")
    end
  end

  describe "#role_nav_items" do
    subject(:keys) { helper.role_nav_items(user).map(&:key) }

    context "when the user has no grants" do
      let_it_be(:user) { create(:user) }

      it { is_expected.to eq([]) }

      context "with the game_breakdown toggle on" do
        before { create(:feature_toggle, key: "game_breakdown", enabled: true) }

        it { is_expected.to eq([]) }
      end
    end

    context "when the user is a subscriber" do
      let_it_be(:user) { create(:user, :subscriber) }

      it { is_expected.to eq(%i[podcast]) }
    end

    context "when the user is an editor" do
      let_it_be(:user) { create(:user, :editor) }

      it { is_expected.to eq(%i[manage_news notification_settings]) }
    end

    context "when the user is a judge" do
      let_it_be(:user) { create(:user, :judge) }

      context "with the game_breakdown toggle on" do
        before { create(:feature_toggle, key: "game_breakdown", enabled: true) }

        it { is_expected.to eq(%i[protocols breakdowns help]) }
      end

      context "with the game_breakdown toggle off" do
        before { create(:feature_toggle, key: "game_breakdown", enabled: false) }

        it { is_expected.to eq(%i[protocols help]) }
      end

      context "when the game_breakdown toggle was never set" do
        it { is_expected.to eq(%i[protocols help]) }
      end
    end

    context "when the user is an admin" do
      let_it_be(:user) { create(:user, :admin) }

      context "with the game_breakdown toggle on" do
        before { create(:feature_toggle, key: "game_breakdown", enabled: true) }

        it do
          expect(keys).to eq(%i[podcast protocols breakdowns help manage_news telegram admin notification_settings])
        end

        it "labels and links each item" do
          expect(helper.role_nav_items(user).map { |item| [ item.label, item.path ] }).to eq(
            [
              [ I18n.t("nav.podcast"), podcast_episodes_path ],
              [ I18n.t("nav.protocols"), judge_protocols_path ],
              [ I18n.t("nav.breakdowns"), judge_breakdowns_path ],
              [ I18n.t("nav.help"), help_index_path ],
              [ I18n.t("nav.manage_news"), admin_news_index_path ],
              [ I18n.t("nav.telegram"), admin_telegram_settings_path ],
              [ I18n.t("nav.admin"), Avo::Engine.routes.url_helpers.root_path ],
              [ I18n.t("nav.notification_settings"), edit_notification_settings_path ]
            ]
          )
        end
      end

      context "with the game_breakdown toggle off" do
        it do
          expect(keys).to eq(%i[podcast protocols help manage_news telegram admin notification_settings])
        end
      end
    end
  end
end
