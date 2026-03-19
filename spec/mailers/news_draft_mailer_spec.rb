require "rails_helper"

RSpec.describe NewsDraftMailer do
  describe "#draft_created" do
    let_it_be(:editor) { create(:user, :editor, locale: "ru") }
    let_it_be(:author) { create(:user) }
    let_it_be(:news) { create(:news, title: "Турнир завершён", author: author) }

    let(:mail) { described_class.draft_created(editor, news) }

    it "sends to the editor's email" do
      expect(mail.to).to eq([ editor.email ])
    end

    it "sets the subject with the news title" do
      expect(mail.subject).to include("Турнир завершён")
    end

    it "includes the news title in the HTML body" do
      expect(mail.html_part.body.encoded).to include("Турнир завершён")
    end

    it "includes the news title in the text body" do
      expect(mail.text_part.body.encoded).to include("Турнир завершён")
    end

    it "uses the Russian locale for the subject prefix" do
      expect(mail.subject).to start_with("Новый черновик:")
    end

    context "when editor has an English locale" do
      let_it_be(:en_editor) { create(:user, :editor, locale: "en") }

      let(:mail) { described_class.draft_created(en_editor, news) }

      it "uses the editor's locale for the subject" do
        expect(mail.subject).to start_with("New draft:")
      end
    end
  end
end
