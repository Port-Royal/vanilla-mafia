require "rails_helper"

RSpec.describe "Redesigned help pages" do
  include_context "with the new design"

  let(:document) { Nokogiri::HTML(response.body) }
  let(:main) { document.at_css("main") }
  let(:rows) { document.css("#help-pages li") }
  let(:contents_links) { document.css("nav#help-contents a") }
  let(:section_headings) { document.css("#help-body h2") }

  def toggle(key)
    FeatureToggle.create!(key:, enabled: true)
  end

  describe "GET /help" do
    context "when the new design is off" do
      before do
        FeatureToggle.where(key: DesignPreference::TOGGLE_KEY).update_all(enabled: false)
        get help_index_path
      end

      it "renders the old list" do
        expect(document.at_css("#help-pages")).to be_nil
      end

      it "still lists the pages" do
        expect(response.body).to include(I18n.t("help.pages.obs-overlay.title"))
      end
    end

    context "with no toggled feature on" do
      before { get help_index_path }

      it "titles the page" do
        expect(main.at_css("h1").text.strip).to eq(I18n.t("help.index.title"))
      end

      it "lists the pages that are not tied to a feature, in order" do
        expect(rows.map { |row| row.at_css("[data-part='title']").text.strip })
          .to eq([ I18n.t("help.pages.obs-overlay.title"), I18n.t("help.pages.podcast-feed.title") ])
      end

      it "links each row to its page" do
        expect(rows.map { |row| row.at_css("a")["href"] })
          .to eq([ help_path(slug: "obs-overlay"), help_path(slug: "podcast-feed") ])
      end

      it "shows the summary under the title" do
        expect(rows.first.at_css("[data-part='summary']").text.strip).to eq(I18n.t("help.pages.obs-overlay.summary"))
      end
    end

    context "with every toggled feature on" do
      before do
        toggle("game_breakdown")
        toggle("live_protocol")
        get help_index_path
      end

      it "lists every page in the controller's order" do
        expect(rows.map { |row| row.at_css("a")["href"] })
          .to eq(HelpController::PAGES.map { |slug| help_path(slug:) })
      end
    end
  end

  describe "GET /help/:slug" do
    context "when the new design is off" do
      before do
        FeatureToggle.where(key: DesignPreference::TOGGLE_KEY).update_all(enabled: false)
        get help_path(slug: "obs-overlay")
      end

      it "renders the old page" do
        expect(document.at_css("#help-body")).to be_nil
      end

      it "still renders the content" do
        expect(response.body).to include(I18n.t("help.pages.obs-overlay.setup_title"))
      end
    end

    context "with the OBS overlay page" do
      before { get help_path(slug: "obs-overlay") }

      it "titles the page" do
        expect(main.at_css("h1").text.strip).to eq(I18n.t("help.pages.obs-overlay.title"))
      end

      it "links back to the help index in the breadcrumb" do
        expect(main.at_css("nav[aria-label='Breadcrumb'] a")["href"]).to eq(help_index_path)
      end

      it "marks the current page in the breadcrumb" do
        expect(main.at_css("nav[aria-label='Breadcrumb'] [aria-current='page']").text.strip)
          .to eq(I18n.t("help.pages.obs-overlay.title"))
      end

      it "renders every section heading" do
        expect(section_headings.map { |heading| heading.text.strip })
          .to eq(%w[setup recommended display judge blocks realtime].map { |key| I18n.t("help.pages.obs-overlay.#{key}_title") })
      end

      it "labels the contents" do
        expect(document.at_css("nav#help-contents")["aria-label"]).to eq(I18n.t("help.redesign.contents"))
      end

      it "lists the sections in the contents, in order" do
        expect(contents_links.map { |link| link.text.strip }).to eq(section_headings.map { |heading| heading.text.strip })
      end

      it "links the contents to the section anchors" do
        expect(contents_links.map { |link| link["href"] }).to eq(section_headings.map { |heading| "##{heading['id']}" })
      end

      it "anchors the sections by their key" do
        expect(section_headings.first["id"]).to eq("setup")
      end

      it "shows the URL examples as code blocks" do
        expect(document.css("#help-body pre").map { |pre| pre.text.strip })
          .to eq([ I18n.t("help.pages.obs-overlay.url_example"), I18n.t("help.pages.obs-overlay.game_url_example") ])
      end

      it "renders the settings tables in the new style" do
        expect(document.css("#help-body table.vm-table").size).to eq(2)
      end

      it "drops the old table style" do
        expect(document.css("#help-body table.data-table")).to be_empty
      end

      it "describes every protocol display setting by its form label" do
        expect(main.text).to include(*%i[hide_roles hide_game_info hide_table_info].map { |setting| Game.human_attribute_name(setting) })
      end

      it "lists the overlay blocks" do
        expect(main.text).to include(I18n.t("help.pages.obs-overlay.block_night"))
      end
    end

    context "with the podcast feed page" do
      before { get help_path(slug: "podcast-feed") }

      it "renders the intro" do
        expect(document.at_css("#help-body [data-part='intro']").text.strip).to eq(I18n.t("help.pages.podcast-feed.intro"))
      end

      it "renders every section heading" do
        expect(section_headings.map { |heading| heading.text.strip })
          .to eq(%w[apple pocket_casts castbox generic privacy].map { |key| I18n.t("help.pages.podcast-feed.#{key}_title") })
      end

      it "numbers the steps of each app" do
        expect(document.css("#help-body ol").map { |list| list.css("li").size }).to eq([ 4, 4, 4, 3 ])
      end
    end

    context "with the game breakdown page" do
      before do
        toggle("game_breakdown")
        get help_path(slug: "game-breakdown")
      end

      it "renders every section heading" do
        expect(section_headings.map { |heading| heading.text.strip })
          .to eq(%w[difference create roles_mode phases automatic warnings result view]
                   .map { |key| I18n.t("help.pages.game-breakdown.#{key}_title") })
      end

      it "renders the closing paragraph" do
        expect(main.text).to include(I18n.t("help.pages.game-breakdown.view_description"))
      end
    end

    context "with the game breakdown toggle off" do
      before { get help_path(slug: "game-breakdown") }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with the live protocol page" do
      let(:key_tables) { document.css("#help-body table.vm-table") }

      before do
        toggle("live_protocol")
        get help_path(slug: "live-protocol")
      end

      it "renders every section heading" do
        expect(section_headings.map { |heading| heading.text.strip })
          .to eq(%w[start keys undo roles network after].map { |key| I18n.t("help.pages.live-protocol.#{key}_title") })
      end

      it "renders one key table per stage" do
        expect(document.css("#help-body h3").map { |heading| heading.text.strip })
          .to eq(%w[all roles deal speech vote night leaving].map { |stage| I18n.t("help.pages.live-protocol.stages.#{stage}") })
      end

      it "gives each key of a stage its own key cap" do
        expect(key_tables.first.css("kbd").map(&:text))
          .to eq([ "F", "G", "X", "Shift+F", "Shift+G", "Ctrl+Z", "H", "Q", "Shift+D" ])
      end

      it "keeps each key cell's text" do
        expect(key_tables.first.css("tbody tr td:first-child").map(&:text))
          .to eq(I18n.t("help.pages.live-protocol.rows.all").map(&:first))
      end

      it "keeps a cell in words as one key cap" do
        expect(key_tables[1].css("kbd").map(&:text)).to include(I18n.t("help.pages.live-protocol.rows.roles").first.first)
      end

      it "names the columns" do
        expect(key_tables.first.css("th").map { |th| th.text.strip })
          .to eq([ I18n.t("help.pages.live-protocol.key"), I18n.t("help.pages.live-protocol.action") ])
      end

      it "lists the start steps" do
        expect(document.css("#help-body ol li").map { |item| item.text.strip }).to eq(I18n.t("help.pages.live-protocol.start"))
      end

      it "renders the closing paragraph" do
        expect(main.text).to include(I18n.t("help.pages.live-protocol.after"))
      end
    end

    context "with the live protocol toggle off" do
      before { get help_path(slug: "live-protocol") }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an unknown page" do
      before { get help_path(slug: "nonexistent-page") }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "page content" do
    def page_texts(node)
      case node
      when Hash then node.values.flat_map { |value| page_texts(value) }
      when Array then node.flat_map { |value| page_texts(value) }
      else [ node.to_s.squish ]
      end
    end

    before do
      toggle("game_breakdown")
      toggle("live_protocol")
    end

    HelpController::PAGES.each do |slug|
      context "with the #{slug} page" do
        let(:page_text) { main.text.squish }
        let(:missing_texts) do
          page_texts(I18n.t("help.pages.#{slug}").except(:title, :summary)).reject { |text| page_text.include?(text) }
        end

        before { get help_path(slug:) }

        it "renders every text the page has in the locale file" do
          expect(missing_texts).to be_empty
        end
      end
    end
  end
end
