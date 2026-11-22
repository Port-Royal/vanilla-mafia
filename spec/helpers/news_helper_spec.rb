require "rails_helper"

RSpec.describe NewsHelper, type: :helper do
  describe "NEWS_PHOTO_VARIANTS" do
    it "crops the card variant to 160x120 at quality 85" do
      expect(NewsHelper::NEWS_PHOTO_VARIANTS[:card]).to eq(resize_to_fill: [ 160, 120 ], saver: { quality: 85 })
    end

    it { expect(NewsHelper::NEWS_PHOTO_VARIANTS).to be_frozen }
  end

  describe "#news_photo_variant" do
    let_it_be(:author) { create(:user) }
    let_it_be(:news) { create(:news, :with_photo, author: author) }
    let(:photo) { news.photos.first }

    it "returns a thumbnail variant at 800x600 with quality 85" do
      variant = helper.news_photo_variant(photo, :thumbnail)
      expect(variant.variation.transformations[:resize_to_limit]).to eq([ 800, 600 ])
      expect(variant.variation.transformations[:saver]).to eq(quality: 85)
    end

    it "returns a full variant at 1200x900 with quality 90" do
      variant = helper.news_photo_variant(photo, :full)
      expect(variant.variation.transformations[:resize_to_limit]).to eq([ 1200, 900 ])
      expect(variant.variation.transformations[:saver]).to eq(quality: 90)
    end

    it "returns a zoom variant at 2400x1800 with quality 90" do
      variant = helper.news_photo_variant(photo, :zoom)
      expect(variant.variation.transformations[:resize_to_limit]).to eq([ 2400, 1800 ])
      expect(variant.variation.transformations[:saver]).to eq(quality: 90)
    end

    it "returns an admin_form variant at 400x400 with quality 80" do
      variant = helper.news_photo_variant(photo, :admin_form)
      expect(variant.variation.transformations[:resize_to_limit]).to eq([ 400, 400 ])
      expect(variant.variation.transformations[:saver]).to eq(quality: 80)
    end

    it "returns a card variant cropped to 160x120 with quality 85" do
      variant = helper.news_photo_variant(photo, :card)
      expect(variant.variation.transformations[:resize_to_fill]).to eq([ 160, 120 ])
      expect(variant.variation.transformations[:saver]).to eq(quality: 85)
    end

    it "raises KeyError for an unknown variant name" do
      expect { helper.news_photo_variant(photo, :bogus) }.to raise_error(KeyError)
    end
  end

  describe "#news_related_links" do
    around { |example| I18n.with_locale(:ru) { example.run } }

    let_it_be(:season) { create(:competition, :season, name: "Сезон 5") }
    let_it_be(:game) { create(:game, competition: season, game_number: 3) }
    let_it_be(:yakov) { create(:player, name: "Яков") }
    let_it_be(:anna) { create(:player, name: "Анна") }
    let_it_be(:boris) { create(:player, name: "Борис") }
    let_it_be(:linked) { create(:news, :published, competition: season, game:) }
    let_it_be(:bare) { create(:news, :published) }

    before_all do
      # Mentioned as Anna, Yakov, Boris: neither player id order (Yakov, Anna, Boris) nor name order (Anna, Boris,
      # Yakov), so sorting by either would show.
      linked.player_mentions.create!(player: anna)
      linked.player_mentions.create!(player: yakov)
      linked.player_mentions.create!(player: boris)
    end

    let(:links) { helper.news_related_links(linked) }

    it "lists the competition, the game, then players in mention order" do
      expect(links.map(&:kind)).to eq(%i[competition game player player player])
    end

    it "links the competition" do
      expect([ links.first.label, links.first.path ]).to eq([ "Сезон 5", competition_path(slug: season.slug) ])
    end

    it "labels the game with its own competition, even a season" do
      expect([ links.second.label, links.second.path ]).to eq([ "Сезон 5 · Игра 3", game_path(game) ])
    end

    it "lists mentioned players in the order they were mentioned" do
      expect(links.last(3).map { |link| [ link.label, link.path ] })
        .to eq([ [ "Анна", player_path(anna) ], [ "Яков", player_path(yakov) ], [ "Борис", player_path(boris) ] ])
    end

    it "returns nothing for news without links" do
      expect(helper.news_related_links(bare)).to eq([])
    end
  end
end
