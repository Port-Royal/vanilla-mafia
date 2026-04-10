require "rails_helper"

RSpec.describe NewsPlayerMention do
  let_it_be(:author) { create(:user) }
  let_it_be(:news) { create(:news, author: author) }
  let_it_be(:player) { create(:player) }

  describe "associations" do
    it "belongs to news" do
      mention = NewsPlayerMention.create!(news: news, player: player)
      expect(mention.news).to eq(news)
    end

    it "belongs to a player" do
      mention = NewsPlayerMention.create!(news: news, player: player)
      expect(mention.player).to eq(player)
    end
  end

  describe "validations" do
    it "requires news" do
      mention = NewsPlayerMention.new(player: player)
      expect(mention).not_to be_valid
    end

    it "requires a player" do
      mention = NewsPlayerMention.new(news: news)
      expect(mention).not_to be_valid
    end

    it "enforces uniqueness of player per news" do
      NewsPlayerMention.create!(news: news, player: player)
      duplicate = NewsPlayerMention.new(news: news, player: player)
      expect(duplicate).not_to be_valid
    end

    it "allows the same player to be mentioned across different news articles" do
      other = create(:news, author: author)
      NewsPlayerMention.create!(news: news, player: player)
      second = NewsPlayerMention.new(news: other, player: player)
      expect(second).to be_valid
    end
  end
end
