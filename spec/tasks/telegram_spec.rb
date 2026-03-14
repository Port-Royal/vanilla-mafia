require "rails_helper"
require "rake"

RSpec.describe "telegram rake tasks" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("telegram:set_webhook")
    Rake::Task["telegram:set_webhook"].reenable
    Rake::Task["telegram:delete_webhook"].reenable
  end

  describe "telegram:set_webhook" do
    let(:result) { Telegram::RegisterWebhookService::Result.new(success: true, description: "Webhook was set") }

    before do
      allow(Telegram::RegisterWebhookService).to receive(:call).and_return(result)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("WEBHOOK_URL").and_return("https://example.com/webhooks/telegram")
    end

    it "calls RegisterWebhookService with the WEBHOOK_URL" do
      Rake::Task["telegram:set_webhook"].execute
      expect(Telegram::RegisterWebhookService).to have_received(:call)
        .with(url: "https://example.com/webhooks/telegram")
    end
  end

  describe "telegram:delete_webhook" do
    let(:result) { Telegram::RegisterWebhookService::Result.new(success: true, description: "Webhook was deleted") }

    before do
      allow(Telegram::RegisterWebhookService).to receive(:delete).and_return(result)
    end

    it "calls RegisterWebhookService.delete" do
      Rake::Task["telegram:delete_webhook"].execute
      expect(Telegram::RegisterWebhookService).to have_received(:delete)
    end
  end
end
