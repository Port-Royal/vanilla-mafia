require "rails_helper"

RSpec.describe User, type: :model do
  describe "account change notifications" do
    let(:user) { create(:user) }

    before { ActionMailer::Base.deliveries.clear }

    describe "email change" do
      it "sends an email_changed notification to the original email" do
        original_email = user.email
        new_email = "new-#{SecureRandom.hex(4)}@example.com"

        user.update!(email: new_email)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq(I18n.t("devise.mailer.email_changed.subject"))
        expect(mail.to).to eq([ original_email ])
      end

      it "does not send a notification when email is unchanged" do
        user

        expect {
          user.update!(notify_on_news_draft: false)
        }.not_to(change { ActionMailer::Base.deliveries.size })
      end
    end

    describe "password change" do
      it "sends a password_change notification to the current email" do
        user.update!(password: "NewStr0ng!pass23", password_confirmation: "NewStr0ng!pass23")

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq(I18n.t("devise.mailer.password_change.subject"))
        expect(mail.to).to eq([ user.email ])
      end

      it "does not send a notification when password is unchanged" do
        user

        expect {
          user.update!(notify_on_news_draft: false)
        }.not_to(change { ActionMailer::Base.deliveries.size })
      end
    end
  end
end
