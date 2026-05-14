require "rails_helper"

RSpec.describe TelegramAuthor, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:player).optional }
  end

  describe "#ensure_user!" do
    context "when user is already linked" do
      let(:user) { create(:user) }
      let(:author) { create(:telegram_author, telegram_user_id: 42, user: user) }

      it "returns the existing user" do
        expect(author.ensure_user!).to eq(user)
      end

      it "does not create a new user" do
        author
        expect { author.ensure_user! }.not_to change(User, :count)
      end
    end

    context "when no user but player is linked" do
      let(:player) { create(:player) }
      let(:author) { create(:telegram_author, telegram_user_id: 42, user: nil, player: player) }

      it "creates a stub user linked to the player" do
        author
        expect { author.ensure_user! }.to change(User, :count).by(1)
        expect(author.reload.user.player).to eq(player)
      end

      it "marks the user as a telegram stub" do
        expect(author.ensure_user!.stub_source).to eq("telegram")
      end

      it "locks the stub user out of authentication" do
        stub = author.ensure_user!
        expect(stub.access_locked?).to be true
      end

      it "caches the user on the telegram author" do
        stub = author.ensure_user!
        expect(author.reload.user_id).to eq(stub.id)
      end

      it "is idempotent on repeat calls" do
        first = author.ensure_user!
        expect { author.ensure_user! }.not_to change(User, :count)
        expect(author.ensure_user!).to eq(first)
      end

      context "when a stub user already exists for the player" do
        let(:existing_stub) do
          u = User.new(
            player: player,
            stub_source: "telegram",
            email: "telegram-#{player.id}@stub.invalid",
            password: SecureRandom.hex(32)
          )
          u.save!(validate: false)
          u.lock_access!
          u
        end

        it "reuses the existing stub" do
          existing_stub
          author
          expect { author.ensure_user! }.not_to change(User, :count)
          expect(author.ensure_user!).to eq(existing_stub)
        end
      end
    end

    context "when neither user nor player is linked" do
      let(:author) { create(:telegram_author, telegram_user_id: 42, user: nil, player: nil) }

      it "returns nil" do
        expect(author.ensure_user!).to be_nil
      end

      it "does not create a user" do
        author
        expect { author.ensure_user! }.not_to change(User, :count)
      end
    end
  end

  describe "validations" do
    subject { build(:telegram_author) }

    it { is_expected.to validate_presence_of(:telegram_user_id) }
    it { is_expected.to validate_uniqueness_of(:telegram_user_id) }
    it { is_expected.to validate_numericality_of(:telegram_user_id).only_integer }
  end

  describe ".whitelisted?" do
    let_it_be(:author) { create(:telegram_author, telegram_user_id: 42) }

    it "returns true for a whitelisted telegram_user_id" do
      expect(described_class).to be_whitelisted(42)
    end

    it "returns false for an unknown telegram_user_id" do
      expect(described_class).not_to be_whitelisted(999)
    end
  end

  describe ".find_by_telegram_user_id" do
    let_it_be(:author) { create(:telegram_author, telegram_user_id: 42) }

    it "returns the author for a known telegram_user_id" do
      expect(described_class.find_by_telegram_user_id(42)).to eq(author)
    end

    it "returns nil for an unknown telegram_user_id" do
      expect(described_class.find_by_telegram_user_id(999)).to be_nil
    end
  end
end
