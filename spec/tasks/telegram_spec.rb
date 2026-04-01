require "rails_helper"
require "rake"

RSpec.describe "telegram rake tasks" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("telegram:set_webhook")
    Rake::Task["telegram:set_webhook"].reenable
    Rake::Task["telegram:delete_webhook"].reenable
    Rake::Task["telegram:import_history"].reenable
  end

  describe "telegram:set_webhook" do
    let(:result) { Telegram::RegisterWebhookService::Result.new(success: true, description: "Webhook was set") }

    before do
      allow(Telegram::RegisterWebhookService).to receive(:call).and_return(result)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("WEBHOOK_URL").and_return("https://example.com/webhooks/telegram")
    end

    it "calls RegisterWebhookService with the WEBHOOK_URL" do
      Rake::Task["telegram:set_webhook"].invoke
      expect(Telegram::RegisterWebhookService).to have_received(:call)
        .with(url: "https://example.com/webhooks/telegram")
    end
  end

  describe "telegram:import_history" do
    let(:export_dir) { Rails.root.join("tmp", "telegram_export_rake_test") }
    let(:from_id) { "user123456" }
    let_it_be(:user) { create(:user, email: "author@example.com") }
    let(:long_text) { "A" * 600 }

    before do
      FileUtils.mkdir_p(export_dir)
      data = {
        "name" => "Test Chat",
        "type" => "private_supergroup",
        "messages" => [
          { "type" => "message", "from_id" => from_id, "text" => long_text, "date" => "2023-01-15T10:00:00" }
        ]
      }
      File.write(export_dir.join("result.json"), JSON.generate(data))
    end

    after do
      FileUtils.rm_rf(export_dir)
    end

    it "creates News drafts from export" do
      expect {
        Rake::Task["telegram:import_history"].invoke(export_dir.to_s, from_id, user.id.to_s)
      }.to change(News, :count).by(1)

      news = News.last
      expect(news.status).to eq("draft")
      expect(news.author).to eq(user)
      expect(news.created_at).to eq(Time.zone.parse("2023-01-15T10:00:00"))
    end

    it "aborts when arguments are missing" do
      expect { Rake::Task["telegram:import_history"].invoke }.to raise_error(SystemExit)
    end

    it "aborts when user is not found" do
      expect {
        Rake::Task["telegram:import_history"].invoke(export_dir.to_s, from_id, "999999")
      }.to raise_error(SystemExit)
    end
  end

  describe "telegram:delete_webhook" do
    let(:result) { Telegram::RegisterWebhookService::Result.new(success: true, description: "Webhook was deleted") }

    before do
      allow(Telegram::RegisterWebhookService).to receive(:delete).and_return(result)
    end

    it "calls RegisterWebhookService.delete" do
      Rake::Task["telegram:delete_webhook"].invoke
      expect(Telegram::RegisterWebhookService).to have_received(:delete)
    end
  end
end
