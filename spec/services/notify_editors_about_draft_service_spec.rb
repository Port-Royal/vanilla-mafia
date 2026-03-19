require "rails_helper"

RSpec.describe NotifyEditorsAboutDraftService do
  let_it_be(:author) { create(:user, :editor) }
  let_it_be(:news) { create(:news, title: "Test News", author: author) }

  describe ".call" do
    context "when editors have notifications enabled" do
      let_it_be(:editor) { create(:user, :editor, notify_on_news_draft: true) }

      it "sends an email to the editor" do
        expect { described_class.call(news) }
          .to have_enqueued_mail(NewsDraftMailer, :draft_created)
          .with(editor, news)
      end
    end

    context "when an admin has notifications enabled" do
      let_it_be(:admin) { create(:user, :admin, notify_on_news_draft: true) }

      it "sends an email to the admin" do
        expect { described_class.call(news) }
          .to have_enqueued_mail(NewsDraftMailer, :draft_created)
          .with(admin, news)
      end
    end

    context "when editor has notifications disabled" do
      let_it_be(:opted_out_editor) { create(:user, :editor, notify_on_news_draft: false) }

      it "does not send an email" do
        expect { described_class.call(news) }
          .not_to have_enqueued_mail(NewsDraftMailer, :draft_created)
          .with(opted_out_editor, news)
      end
    end

    context "when a regular user has notifications enabled" do
      let_it_be(:regular_user) { create(:user, notify_on_news_draft: true) }

      it "does not send an email to non-editors" do
        expect { described_class.call(news) }
          .not_to have_enqueued_mail(NewsDraftMailer, :draft_created)
          .with(regular_user, news)
      end
    end

    it "excludes the news author from notifications" do
      expect { described_class.call(news) }
        .not_to have_enqueued_mail(NewsDraftMailer, :draft_created)
        .with(author, news)
    end
  end
end
