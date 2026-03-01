require "rails_helper"

RSpec.describe DisputeMailer do
  describe "#dispute_filed" do
    let_it_be(:player) { create(:player, name: "TestPlayer") }
    let_it_be(:owner) { create(:user, player: player) }
    let_it_be(:disputant) { create(:user) }
    let_it_be(:claim) { create(:player_claim, :dispute, user: disputant, player: player) }

    let(:mail) { described_class.dispute_filed(claim) }

    it "sends to the current owner's email" do
      expect(mail.to).to eq([ owner.email ])
    end

    it "sets the subject with the player name" do
      expect(mail.subject).to eq("Оспаривание профиля TestPlayer")
    end

    it "includes the player name in the HTML body" do
      expect(mail.html_part.body.encoded).to include("TestPlayer")
    end

    it "includes the player name in the text body" do
      expect(mail.text_part.body.encoded).to include("TestPlayer")
    end

    it "includes the disputant email in the HTML body" do
      expect(mail.html_part.body.encoded).to include(disputant.email)
    end

    it "includes the disputant email in the text body" do
      expect(mail.text_part.body.encoded).to include(disputant.email)
    end

    context "when the owner has an English locale" do
      let_it_be(:en_player) { create(:player, name: "EnglishPlayer") }
      let_it_be(:en_owner) { create(:user, player: en_player, locale: "en") }
      let_it_be(:en_disputant) { create(:user) }
      let_it_be(:en_claim) { create(:player_claim, :dispute, user: en_disputant, player: en_player) }

      let(:mail) { described_class.dispute_filed(en_claim) }

      it "uses the owner's locale for the subject" do
        expect(mail.subject).to eq("Dispute filed for profile EnglishPlayer")
      end
    end

    context "when no current owner exists" do
      let_it_be(:orphan_player) { create(:player) }
      let_it_be(:temporary_owner) { create(:user, player: orphan_player) }
      let_it_be(:orphan_disputant) { create(:user) }
      let_it_be(:orphan_claim) { create(:player_claim, :dispute, user: orphan_disputant, player: orphan_player) }

      before_all do
        temporary_owner.update_columns(player_id: nil)
      end

      let(:mail) { described_class.dispute_filed(orphan_claim) }

      it "does not send an email" do
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
