require 'rails_helper'

RSpec.describe Award, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:player_awards).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:players).through(:player_awards) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe "icon attachment" do
    let(:award) { build(:award) }

    context "with an allowed image content type" do
      before do
        award.icon.attach(io: StringIO.new("i"), filename: "i.png", content_type: "image/png")
      end

      it "is valid" do
        expect(award).to be_valid
      end
    end

    context "with an SVG content type" do
      before do
        award.icon.attach(io: StringIO.new("<svg/>"), filename: "i.svg", content_type: "image/svg+xml")
      end

      it "is valid (admin-only upload)" do
        expect(award).to be_valid
      end
    end

    context "with a disallowed content type" do
      before do
        award.icon.attach(io: StringIO.new("i"), filename: "i.exe", content_type: "application/octet-stream")
      end

      it "is invalid" do
        expect(award).not_to be_valid
        expect(award.errors[:icon]).to include(I18n.t("errors.messages.content_type"))
      end
    end

    context "when over the size limit" do
      before do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("x"),
          filename: "big.png",
          content_type: "image/png"
        )
        blob.update_columns(byte_size: Award::MAX_ICON_SIZE + 1)
        award.icon.attach(blob)
      end

      it "is invalid" do
        expect(award).not_to be_valid
        expect(award.errors[:icon]).to include(
          I18n.t("errors.messages.file_size", count: Award::MAX_ICON_SIZE / 1.megabyte)
        )
      end
    end
  end

  describe '.for_players' do
    let_it_be(:player_award) { create(:award, staff: false) }
    let_it_be(:staff_award) { create(:award, staff: true) }

    it 'returns awards where staff is false' do
      expect(described_class.for_players).to include(player_award)
      expect(described_class.for_players).not_to include(staff_award)
    end
  end

  describe '.for_staff' do
    let_it_be(:player_award) { create(:award, staff: false) }
    let_it_be(:staff_award) { create(:award, staff: true) }

    it 'returns awards where staff is true' do
      expect(described_class.for_staff).to include(staff_award)
      expect(described_class.for_staff).not_to include(player_award)
    end
  end

  describe '.ordered' do
    let_it_be(:third) { create(:award, position: 3) }
    let_it_be(:first) { create(:award, position: 1) }
    let_it_be(:second) { create(:award, position: 2) }

    it 'orders by position ascending' do
      expect(described_class.ordered).to eq([ first, second, third ])
    end
  end
end
