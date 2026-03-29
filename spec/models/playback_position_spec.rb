require "rails_helper"

RSpec.describe PlaybackPosition, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:episode) }
  end

  describe "validations" do
    subject { build(:playback_position) }

    it { is_expected.to validate_presence_of(:position_seconds) }

    it do
      is_expected.to validate_numericality_of(:position_seconds)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it { is_expected.to validate_inclusion_of(:playback_speed).in_array(PlaybackPosition::VALID_SPEEDS) }

    it { is_expected.to validate_uniqueness_of(:episode_id).scoped_to(:user_id) }
  end

  describe "factory" do
    it "creates a valid record" do
      expect(build(:playback_position)).to be_valid
    end
  end
end
