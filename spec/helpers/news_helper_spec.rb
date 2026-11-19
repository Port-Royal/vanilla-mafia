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
end
