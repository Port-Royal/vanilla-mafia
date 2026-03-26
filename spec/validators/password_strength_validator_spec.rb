require "rails_helper"

RSpec.describe PasswordStrengthValidator do
  subject(:user) { build(:user, password: password, password_confirmation: password) }

  describe "character diversity" do
    context "when password has lowercase, uppercase, and digits" do
      let(:password) { "Abcdef1234" }

      it { is_expected.to be_valid }
    end

    context "when password has lowercase, uppercase, and special characters" do
      let(:password) { 'Abcdef!@#$' }

      it { is_expected.to be_valid }
    end

    context "when password has lowercase, digits, and special characters" do
      let(:password) { 'abcdef12!@' }

      it { is_expected.to be_valid }
    end

    context "when password has uppercase, digits, and special characters" do
      let(:password) { 'ABCDEF12!@' }

      it { is_expected.to be_valid }
    end

    context "when password has all four character types" do
      let(:password) { 'Abcdef12!@' }

      it { is_expected.to be_valid }
    end

    context "when password has only lowercase and uppercase" do
      let(:password) { "Abcdefghij" }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end

    context "when password has only lowercase and digits" do
      let(:password) { "abcdef1234" }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end

    context "when password has only lowercase characters" do
      let(:password) { "abcdefghij" }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end

    context "when password has only uppercase and digits" do
      let(:password) { "ABCDEF1234" }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end

    context "when password has only lowercase and special characters" do
      let(:password) { 'abcdef!@!!' }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end

    context "when password has only uppercase and special characters" do
      let(:password) { 'ABCDEF!@!!' }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end

    context "when password has only digits and special characters" do
      let(:password) { '123456!@!!' }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
      end
    end
  end

  describe "common password blocklist" do
    context "when password is a common password" do
      let(:password) { 'Password123!' }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.common_password")
        )
      end
    end

    context "when password is a common password in different case" do
      let(:password) { 'password123!' }

      it "is invalid" do
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(
          I18n.t("activerecord.errors.models.user.attributes.password.common_password")
        )
      end
    end

    context "when password is not common" do
      let(:password) { 'Xylocarpa7!z' }

      it { is_expected.to be_valid }
    end
  end

  describe "skipping validation" do
    context "when password is blank (e.g., OAuth user)" do
      let(:user) { build(:user, password: nil, password_confirmation: nil) }

      it "skips password strength validation" do
        user.valid?
        expect(user.errors[:password]).not_to include(
          I18n.t("activerecord.errors.models.user.attributes.password.insufficient_diversity")
        )
        expect(user.errors[:password]).not_to include(
          I18n.t("activerecord.errors.models.user.attributes.password.common_password")
        )
      end
    end
  end
end
