require "rails_helper"
require "rake"

RSpec.describe "telegram rake tasks" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("telegram:set_webhook")
    Rake::Task["telegram:set_webhook"].reenable
    Rake::Task["telegram:delete_webhook"].reenable
    Rake::Task["telegram:generate_import_migration"].reenable
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

  describe "telegram:generate_import_migration" do
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
      Dir.glob(Rails.root.join("db", "migrate", "*_import_telegram_news_drafts.rb")).each do |f|
        FileUtils.rm_f(f)
      end
    end

    it "generates a migration file" do
      Rake::Task["telegram:generate_import_migration"].invoke(export_dir.to_s, from_id, "author@example.com")

      migration_files = Dir.glob(Rails.root.join("db", "migrate", "*_import_telegram_news_drafts.rb"))
      expect(migration_files.size).to eq(1)
    end

    it "aborts when arguments are missing" do
      expect { Rake::Task["telegram:generate_import_migration"].invoke }.to raise_error(SystemExit)
    end

    it "aborts when user is not found" do
      expect {
        Rake::Task["telegram:generate_import_migration"].invoke(export_dir.to_s, from_id, "nonexistent@example.com")
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
