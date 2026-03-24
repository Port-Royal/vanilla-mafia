require "rails_helper"

RSpec.describe PlaylistEpisode, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:playlist) }
    it { is_expected.to belong_to(:episode) }
  end

  describe "validations" do
    subject { build(:playlist_episode) }

    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than(0) }

    it "validates uniqueness of episode within a playlist" do
      existing = create(:playlist_episode)
      duplicate = build(:playlist_episode, playlist: existing.playlist, episode: existing.episode)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.where(:episode_id, :taken)).to be_present
    end

    it "validates uniqueness of position within a playlist" do
      existing = create(:playlist_episode)
      duplicate = build(:playlist_episode, playlist: existing.playlist, position: existing.position)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.where(:position, :taken)).to be_present
    end
  end

  describe "association ordering" do
    let(:playlist) { create(:playlist) }
    let!(:third) { create(:playlist_episode, playlist: playlist, position: 3) }
    let!(:first) { create(:playlist_episode, playlist: playlist, position: 1) }
    let!(:second) { create(:playlist_episode, playlist: playlist, position: 2) }

    it "orders by position" do
      expect(playlist.playlist_episodes).to eq([ first, second, third ])
    end
  end
end
