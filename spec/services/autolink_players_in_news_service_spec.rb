require "rails_helper"

RSpec.describe AutolinkPlayersInNewsService do
  let_it_be(:alex) { create(:player, name: "Alex") }
  let_it_be(:alex_smith) { create(:player, name: "Alex Smith") }
  let_it_be(:ivan) { create(:player, name: "Иван") }

  before { create(:feature_toggle, key: "news_autolink_players", enabled: true) }

  def build_news(html)
    create(:news, content: html)
  end

  def rewritten_html(news)
    described_class.call(news)
    news.reload.content.body.to_html
  end

  describe ".call" do
    context "when the feature toggle is disabled" do
      before { FeatureToggle.find_by!(key: "news_autolink_players").update!(enabled: false) }

      it "does not modify the content" do
        news = build_news("<div>Alex scored a goal</div>")
        expect { described_class.call(news) }
          .not_to change { news.reload.content.body.to_html }
      end
    end

    context "when the content is blank" do
      it "does not raise" do
        news = build_news("")
        expect { described_class.call(news) }.not_to raise_error
      end
    end

    it "wraps a single player mention in a link to the profile" do
      news = build_news("<div>Alex scored a goal</div>")
      expect(rewritten_html(news)).to include(%(<a href="/players/#{alex.slug}">Alex</a>))
    end

    it "links only the first occurrence of a player name" do
      news = build_news("<div>Alex passed to Alex again</div>")
      html = rewritten_html(news)
      expect(html.scan(%r{<a href="/players/#{alex.slug}">Alex</a>}).size).to eq(1)
      expect(html).to include("to Alex again")
    end

    it "links each player once when multiple players are mentioned" do
      news = build_news("<div>Alex passed to Иван</div>")
      html = rewritten_html(news)
      expect(html).to include(
        %(<a href="/players/#{alex.slug}">Alex</a> passed to <a href="/players/#{ivan.slug}">Иван</a>)
      )
    end

    it "preserves text that appears before the first match" do
      news = build_news("<div>Hello Alex world</div>")
      expect(rewritten_html(news)).to include(%(Hello <a href="/players/#{alex.slug}">Alex</a> world))
    end

    it "links matches regardless of the order they appear in the text" do
      news = build_news("<div>Иван then Alex</div>")
      html = rewritten_html(news)
      expect(html).to include(
        %(<a href="/players/#{ivan.slug}">Иван</a> then <a href="/players/#{alex.slug}">Alex</a>)
      )
    end

    it "links the first occurrence across separate elements" do
      news = build_news("<div><p>Alex scored</p><p>Alex passed again</p></div>")
      html = rewritten_html(news)
      expect(html.scan(%r{<a href="/players/#{alex.slug}">Alex</a>}).size).to eq(1)
      expect(html).to include("Alex passed again")
    end

    it "keeps a non-overlapping later match when an earlier overlap is dropped" do
      news = build_news("<div>Alex Smith passed to Иван</div>")
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/players/#{alex_smith.slug}">Alex Smith</a>))
      expect(html).to include(%(<a href="/players/#{ivan.slug}">Иван</a>))
      expect(html).not_to include(%(<a href="/players/#{alex.slug}">))
    end

    it "matches case-insensitively and preserves original casing" do
      news = build_news("<div>ALEX and alex play together</div>")
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/players/#{alex.slug}">ALEX</a>))
      expect(html).to include("and alex play")
    end

    it "does not match a name that is a substring of a longer word" do
      news = build_news("<div>Alexander scored</div>")
      expect(rewritten_html(news)).not_to include(%(<a href="/players/#{alex.slug}">))
    end

    it "does not match a name preceded by a letter" do
      news = build_news("<div>xxAlex scored</div>")
      expect(rewritten_html(news)).not_to include(%(<a href="/players/#{alex.slug}">))
    end

    it "does not match Cyrillic name inside a longer word" do
      news = build_news("<div>Иванов забил гол</div>")
      expect(rewritten_html(news)).not_to include(%(<a href="/players/#{ivan.slug}">))
    end

    it "prefers the longer player name when names overlap" do
      news = build_news("<div>Alex Smith played well</div>")
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/players/#{alex_smith.slug}">Alex Smith</a>))
      expect(html).not_to include(%(<a href="/players/#{alex.slug}">Alex</a>))
    end

    it "skips text already inside an anchor tag" do
      news = build_news(%(<div><a href="/other">Alex</a> scored</div>))
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/other">Alex</a>))
      expect(html).not_to include(%(<a href="/players/#{alex.slug}">))
    end

    it "leaves content unchanged when no players are mentioned" do
      news = build_news("<div>Nobody relevant here</div>")
      expect(news).not_to receive(:update!)
      expect { described_class.call(news) }
        .not_to change { news.reload.content.body.to_html }
    end

    it "does nothing when there are no players in the database" do
      allow(Player).to receive(:pluck).with(:id, :name, :slug).and_return([])
      news = build_news("<div>Alex scored</div>")
      expect(news).not_to receive(:update!)
      described_class.call(news)
    end

    it "processes text nodes in sibling elements after one element" do
      news = build_news("<div><p>Alex</p><p>Иван</p></div>")
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/players/#{alex.slug}">Alex</a>))
      expect(html).to include(%(<a href="/players/#{ivan.slug}">Иван</a>))
    end

    it "processes text after an existing anchor" do
      news = build_news(%(<div><a href="/other">Link</a> and Иван</div>))
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/other">Link</a>))
      expect(html).to include(%(<a href="/players/#{ivan.slug}">Иван</a>))
    end

    it "escapes regex metacharacters in player names" do
      dotted = create(:player, name: "A.B")
      news = build_news("<div>AXB did not score, A.B did</div>")
      html = rewritten_html(news)
      expect(html).to include(%(<a href="/players/#{dotted.slug}">A.B</a>))
      expect(html).not_to include(%(<a href="/players/#{dotted.slug}">AXB</a>))
    end

    it "replaces the original text node rather than duplicating it" do
      news = build_news("<div>Alex scored a goal</div>")
      html = rewritten_html(news)
      expect(html.scan("Alex").size).to eq(1)
      expect(html.scan("scored a goal").size).to eq(1)
    end

    context "Russian morphology" do
      it "links Ивана (genitive) back to Иван preserving the matched form" do
        news = build_news("<div>пас от Ивана был точным</div>")
        expect(rewritten_html(news)).to include(%(<a href="/players/#{ivan.slug}">Ивана</a>))
      end

      it "links Иваном (instrumental)" do
        news = build_news("<div>игра с Иваном удалась</div>")
        expect(rewritten_html(news)).to include(%(<a href="/players/#{ivan.slug}">Иваном</a>))
      end

      it "does not match the surname Иванов" do
        news = build_news("<div>Иванов забил гол</div>")
        expect(rewritten_html(news)).not_to include(%(<a href="/players/#{ivan.slug}">))
      end

      it "links a multi-word feminine nickname across all cases" do
        pot = create(:player, name: "Свирепая Кастрюля")
        news = build_news("<div>встретил Свирепую Кастрюлю на поле</div>")
        expect(rewritten_html(news)).to include(
          %(<a href="/players/#{pot.slug}">Свирепую Кастрюлю</a>)
        )
      end

      it "links a multi-word feminine nickname in genitive" do
        pot = create(:player, name: "Свирепая Кастрюля")
        news = build_news("<div>гол Свирепой Кастрюли был красивым</div>")
        expect(rewritten_html(news)).to include(
          %(<a href="/players/#{pot.slug}">Свирепой Кастрюли</a>)
        )
      end

      it "links a plural-originated nickname in genitive plural" do
        team = create(:player, name: "Грибочки")
        news = build_news("<div>победа Грибочков была заслуженной</div>")
        expect(rewritten_html(news)).to include(
          %(<a href="/players/#{team.slug}">Грибочков</a>)
        )
      end

      it "links a plural-originated nickname in instrumental plural" do
        team = create(:player, name: "Вдохи")
        news = build_news("<div>играли с Вдохами в финале</div>")
        expect(rewritten_html(news)).to include(
          %(<a href="/players/#{team.slug}">Вдохами</a>)
        )
      end
    end

    context "news-player mentions" do
      it "records a mention for each linked player" do
        news = build_news("<div>Alex passed to Иван</div>")
        described_class.call(news)
        expect(news.reload.mentioned_players).to contain_exactly(alex, ivan)
      end

      it "does not create mentions when no players match" do
        news = build_news("<div>Nobody relevant here</div>")
        expect { described_class.call(news) }.not_to change(NewsPlayerMention, :count)
      end

      it "does not create duplicate mentions when the service is run twice" do
        news = build_news("<div>Alex scored a goal</div>")
        described_class.call(news)
        expect { described_class.call(news) }.not_to change(NewsPlayerMention, :count)
      end

      it "records only one mention per player even when the name appears multiple times" do
        news = build_news("<div>Alex passed to Alex again</div>")
        described_class.call(news)
        expect(news.reload.mentioned_players).to contain_exactly(alex)
      end

      it "records the longer player when overlapping names exist" do
        news = build_news("<div>Alex Smith played well</div>")
        described_class.call(news)
        expect(news.reload.mentioned_players).to contain_exactly(alex_smith)
      end

      it "does not record mentions when the feature toggle is disabled" do
        FeatureToggle.find_by!(key: "news_autolink_players").update!(enabled: false)
        news = build_news("<div>Alex scored a goal</div>")
        expect { described_class.call(news) }.not_to change(NewsPlayerMention, :count)
      end
    end
  end
end
