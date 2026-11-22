require "rails_helper"

RSpec.describe "Redesigned news pages" do
  include_context "with the new design"

  let(:document) { Nokogiri::HTML(response.body) }
  let(:cards) { document.css("article[data-news-id]") }
  let(:card) { ->(news) { document.at_css("article[data-news-id='#{news.id}']") } }
  let(:part) { ->(news, name) { card.(news).at_css("[data-part='#{name}']") } }

  let_it_be(:writer) { create(:player, name: "Маринад") }
  let_it_be(:author) { create(:user, player: writer) }
  let_it_be(:anonymous_author) { create(:user) }
  let_it_be(:season) { create(:competition, :season, name: "Сезон 5") }
  let_it_be(:older) do
    create(:news, :published, author:, title: "Мафия для начинающих", published_at: 3.days.ago, competition: season,
                              content: "<p>#{'Первый абзац о правилах. ' * 8}</p><p>#{'Второй абзац о тактике. ' * 12}</p>")
  end
  let_it_be(:newer) { create(:news, :published, author: anonymous_author, title: "Итоги серии", published_at: 1.day.ago) }
  let_it_be(:draft) { create(:news, author:, title: "Черновик") }

  def toggle(key, value = nil)
    FeatureToggle.create!(key:, enabled: true, value:)
  end

  describe "GET /news" do
    context "when the new design is off" do
      before do
        FeatureToggle.where(key: DesignPreference::TOGGLE_KEY).update_all(enabled: false)
        get news_index_path
      end

      it "renders the old list" do
        expect(cards).to be_empty
      end
    end

    context "with the default paging" do
      before { get news_index_path }

      it "titles the page" do
        expect(document.at_css("main h1").text.strip).to eq(I18n.t("news.index.title"))
      end

      it "lists visible news newest first" do
        expect(cards.map { |article| article.at_css("h2").text.strip }).to eq([ "Итоги серии", "Мафия для начинающих" ])
      end

      it "links the title to the article" do
        expect(card.(older).at_css("h2 a")["href"]).to eq(news_path(older))
      end

      it "starts the meta line with the date" do
        expect(part.(older, "meta").text.squish).to start_with(DatetimeFormatter.call(older.published_at, type: :date))
      end

      it "links the author's player profile" do
        expect(part.(older, "author")["href"]).to eq(player_path(writer))
      end

      it "leaves out an author without a player" do
        expect(part.(newer, "author")).to be_nil
      end

      it "links the competition the news is about" do
        expect(part.(older, "competition")["href"]).to eq(competition_path(slug: season.slug))
      end

      it "has no competition link when none is linked" do
        expect(part.(newer, "competition")).to be_nil
      end

      it "shows an excerpt cut like the home page cards" do
        expect(part.(older, "excerpt").text.strip).to eq(older.truncated_content(250).to_plain_text.strip)
      end

      it "offers to read the whole article" do
        expect(part.(older, "read-more")["href"]).to eq(news_path(older))
      end

      it "shows no thumbnail without photos" do
        expect(part.(older, "thumbnail")).to be_nil
      end

      it "shows no edit link to visitors" do
        expect(part.(older, "edit")).to be_nil
      end
    end

    context "when an article has a photo" do
      let_it_be(:pictured) { create(:news, :published, :with_photo, author:, published_at: 2.days.ago) }

      before { get news_index_path }

      it "shows its thumbnail" do
        expect(part.(pictured, "thumbnail")["alt"]).to eq("")
      end
    end

    context "when an article's only attachment cannot be resized" do
      let_it_be(:odd) { create(:news, :published, author:, published_at: 2.days.ago) }

      before_all do
        blob = ActiveStorage::Blob.create_and_upload!(io: Rails.root.join("spec/fixtures/files/document.pdf").open,
                                                      filename: "document.pdf", content_type: "application/pdf")
        ActiveStorage::Attachment.create!(record: odd, name: "photos", blob:)
      end

      before { get news_index_path }

      it "shows no thumbnail" do
        expect(part.(odd, "thumbnail")).to be_nil
      end
    end

    context "when an article has no text" do
      let_it_be(:empty) { create(:news, :published, author:, published_at: 2.days.ago) }

      before { get news_index_path }

      it "shows no excerpt" do
        expect(part.(empty, "excerpt")).to be_nil
      end
    end

    context "when an article has tags" do
      let_it_be(:tag) { create(:tag, name: "Гайды") }

      before do
        older.tags << tag
        get news_index_path
      end

      after { older.tags.delete(tag) }

      it "shows them as pills" do
        expect(card.(older).css(".vm-pill").map { |pill| pill.text.strip }).to eq([ "Гайды" ])
      end
    end

    context "when the viewer edits news" do
      before do
        sign_in create(:user, :editor)
        get news_index_path
      end

      it "links each card to its editor" do
        expect(part.(older, "edit")["href"]).to eq(edit_admin_news_path(older))
      end
    end

    context "when the article length toggle is set" do
      before do
        toggle("news_max_article_length", "30")
        get news_index_path
      end

      it "still shows the card excerpt" do
        expect(part.(older, "excerpt").text.strip).to eq(older.truncated_content(250).to_plain_text.strip)
      end
    end

    context "when several news link different competitions" do
      let(:query_count) do
        lambda do
          count = 0
          counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get news_index_path }
          count
        end
      end
      # Queries with the three links, then with none: the links should cost exactly one extra query.
      let(:linked_and_unlinked) do
        linked = query_count.()
        News.update_all(competition_id: nil)
        [ linked, query_count.() ]
      end

      before_all do
        2.times { |i| create(:news, :published, author:, competition: create(:competition, :series), published_at: (i + 4).days.ago) }
      end

      it "loads their competitions in one query" do
        expect(linked_and_unlinked.first - linked_and_unlinked.last).to eq(1)
      end
    end

    context "when there are no visible news" do
      before do
        News.where.not(id: draft.id).update_all(status: "draft")
        get news_index_path
      end

      it "says so" do
        expect(document.at_css("main").text).to include(I18n.t("news.index.empty"))
      end
    end

    context "with classic pagination" do
      before do
        toggle("news_classic_pagination")
        toggle("news_per_page", "1")
        get news_index_path
      end

      it "shows one page of cards" do
        expect(cards.size).to eq(1)
      end

      it "shows the page navigation with the current page marked" do
        expect(document.at_css("main nav [aria-current='page']").text.strip).to eq("1")
      end
    end

    context "with infinite scroll" do
      before do
        toggle("news_infinite_scroll")
        toggle("news_per_page", "1")
      end

      context "when loading the page" do
        before { get news_index_path }

        it "puts the cards in the scrolling frame" do
          expect(document.css("turbo-frame#news-list[target='_top'] article[data-news-id]").size).to eq(1)
        end

        it "points the sentinel at the next page" do
          expect(document.at_css("[data-infinite-scroll-target='sentinel']")["data-next-url"])
            .to eq(news_index_path(page: 2, format: :turbo_stream))
        end

        it "shows no page navigation" do
          expect(document.at_css("main nav [aria-current='page']")).to be_nil
        end
      end

      context "when loading the next page" do
        before { get news_index_path(page: 2, format: :turbo_stream) }

        it "appends new cards" do
          expect(response.body).to include("data-news-id=\"#{older.id}\"")
        end
      end
    end
  end

  describe "GET /news/:slug" do
    let(:article) { document.at_css("article#news-article") }
    let(:page_part) { ->(name) { article.at_css("[data-part='#{name}']") } }
    let(:related) { page_part.("related") }

    context "when the new design is off" do
      before do
        FeatureToggle.where(key: DesignPreference::TOGGLE_KEY).update_all(enabled: false)
        get news_path(older)
      end

      it "renders the old page" do
        expect(article).to be_nil
      end
    end

    context "with a linked article" do
      let_it_be(:game) { create(:game, competition: season, game_number: 3) }
      let_it_be(:mentioned) { create(:player, name: "Финчер") }

      before_all do
        older.update!(game:)
        older.player_mentions.create!(player: mentioned)
      end

      before { get news_path(older) }

      it "shows the title" do
        expect(article.at_css("h1").text.strip).to eq("Мафия для начинающих")
      end

      it "links back to the list" do
        expect([ page_part.("back").text.strip, page_part.("back")["href"] ]).to eq([ I18n.t("news.show.back"), news_index_path ])
      end

      it "starts the meta line with the date" do
        expect(page_part.("meta").text.squish).to start_with(DatetimeFormatter.call(older.published_at, type: :date))
      end

      it "links the author's player profile" do
        expect(page_part.("meta").at_css("[data-part='author']")["href"]).to eq(player_path(writer))
      end

      it "shows the text" do
        expect(page_part.("body").text).to include("Второй абзац о тактике.")
      end

      it "styles the text through the article prose rules" do
        expect(page_part.("body")["class"].split).to include("news-prose")
      end

      it "lists the related links without a heading" do
        expect(related.css("li").map { |item| item["data-kind"] }).to eq(%w[competition game player])
      end

      it "captions each related link" do
        expect(related.css("li").map { |item| item.text.squish })
          .to eq([ "#{I18n.t('news.redesign.related.competition')} Сезон 5",
                   "#{I18n.t('news.redesign.related.game')} Сезон 5 · Игра 3",
                   "#{I18n.t('news.redesign.related.player')} Финчер" ])
      end

      it "links the related items" do
        expect(related.css("a").map { |link| link["href"] })
          .to eq([ competition_path(slug: season.slug), game_path(game), player_path(mentioned) ])
      end

      it "shows no photos" do
        expect(page_part.("hero")).to be_nil
      end

      it "shows no edit button to visitors" do
        expect(page_part.("edit")).to be_nil
      end
    end

    context "with an article without links or a claimed author" do
      before { get news_path(newer) }

      it "shows no related block" do
        expect(related).to be_nil
      end

      it "shows no author link" do
        expect(page_part.("meta").at_css("[data-part='author']")).to be_nil
      end
    end

    context "with photos" do
      let_it_be(:pictured) { create(:news, :published, :with_photo, author:, title: "С фото") }

      before_all do
        File.open(Rails.root.join("spec/fixtures/files/selfie.jpg"), "rb") do |file|
          pictured.photos.attach(io: file, filename: "second.jpg", content_type: "image/jpeg")
        end
      end

      before { get news_path(pictured) }

      it "shows the first photo large, opening the zoom" do
        expect(page_part.("hero").attributes.slice("data-controller", "aria-label").transform_values(&:value))
          .to eq("data-controller" => "lightbox", "aria-label" => "С фото")
      end

      it "shows the other photos as zoomable thumbnails" do
        expect(article.css("[data-part='thumbnail'][data-controller='lightbox']").size).to eq(1)
      end

      it "describes a thumbnail with the title, so its zoomed view is named" do
        expect(article.at_css("[data-part='thumbnail'] img")["alt"]).to eq("С фото")
      end
    end

    context "when the viewer edits news" do
      before do
        sign_in create(:user, :editor)
        get news_path(older)
      end

      it "offers an edit button" do
        expect(page_part.("edit")["href"]).to eq(edit_admin_news_path(older))
      end
    end

    context "with a draft" do
      before { get news_path(draft) }

      it "is not found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
