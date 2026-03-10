require "rails_helper"

RSpec.describe Tagging, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:tag) }
    it { is_expected.to belong_to(:taggable) }
  end

  describe "validations" do
    subject { create(:tagging) }

    it { is_expected.to validate_uniqueness_of(:tag_id).scoped_to(:taggable_type, :taggable_id) }
  end
end
