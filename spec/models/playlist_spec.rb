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
end
