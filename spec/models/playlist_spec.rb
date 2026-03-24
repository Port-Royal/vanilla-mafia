require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:playlist_episodes).dependent(:destroy).order(:position) }
    it { is_expected.to have_many(:episodes).through(:playlist_episodes) }
  end

  describe "validations" do
    subject { build(:playlist) }

    it { is_expected.to validate_presence_of(:title) }
  end

  describe "#episodes" do
    it "returns episodes ordered by playlist position" do
      playlist = create(:playlist)
      first_episode = create(:episode)
      second_episode = create(:episode)

      create(:playlist_episode, playlist: playlist, episode: second_episode, position: 2)
      create(:playlist_episode, playlist: playlist, episode: first_episode, position: 1)

      expect(playlist.episodes).to eq([ first_episode, second_episode ])
    end
  end
end
