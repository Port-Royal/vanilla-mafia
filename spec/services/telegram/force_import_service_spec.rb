require "rails_helper"

RSpec.describe Telegram::ForceImportService do
  let_it_be(:operator_user) { create(:user) }
  let_it_be(:operator_author) { create(:telegram_author, telegram_user_id: 12345, user: operator_user) }
  let_it_be(:sender_user) { create(:user) }
  let_it_be(:sender_author) { create(:telegram_author, telegram_user_id: 99999, user: sender_user) }

  let(:operator_chat_id) { 12345 }
  let(:source_chat) { -1001111111111 }
  let(:start_message_id) { 100 }

  let(:single_message_payload) do
    {
      "message_id" => 9001,
      "from" => { "id" => 0, "is_bot" => true },
      "text" => "A" * 50,
      "forward_origin" => {
        "type" => "user",
        "sender_user" => { "id" => 99999, "first_name" => "Sender" },
        "date" => 1_710_000_000
      }
    }
  end

  let(:parsed_link) do
    Telegram::MessageLinkParser::Result.new(
      source_chat: source_chat, message_id: start_message_id, count: 0
    )
  end

  before do
    FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
      ft.enabled = true
      ft.value = ""
      ft.description = "force_import"
    end
    allow(Telegram::BotDmService).to receive(:call).and_return(true)
    allow(NotifyEditorsAboutDraftService).to receive(:call)
    allow(AutolinkPlayersInNewsService).to receive(:call)
  end

  describe ".call (single message)" do
    before do
      allow(Telegram::ForwardMessageService).to receive(:call).and_return(
        Telegram::ForwardMessageService::Result.new(
          success: true, message: single_message_payload, error_code: nil, description: nil
        )
      )
    end

    it "creates exactly one News draft" do
      expect {
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      }.to change(News, :count).by(1)
    end

    it "calls forwardMessage with the parsed link parameters" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::ForwardMessageService).to have_received(:call).with(
        from_chat_id: source_chat, message_id: start_message_id, to_chat_id: operator_chat_id
      )
    end

    it "authors the draft as the sender's linked user" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.author).to eq(sender_user)
    end

    it "sets the draft status to :draft" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.status).to eq("draft")
    end

    it "uses the message text as the title" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.title).to eq("A" * 50)
    end

    it "sets created_at from forward_origin.date" do
      freeze_time do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.created_at).to eq(Time.at(1_710_000_000))
      end
    end

    it "sets telegram_thread_started_at and _last_message_at to original date" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      news = News.last
      expect(news.telegram_thread_started_at).to eq(Time.at(1_710_000_000))
      expect(news.telegram_thread_last_message_at).to eq(Time.at(1_710_000_000))
    end

    it "runs the autolink service on the new draft" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(AutolinkPlayersInNewsService).to have_received(:call).with(News.last)
    end

    it "notifies editors" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(NotifyEditorsAboutDraftService).to have_received(:call).with(News.last)
    end

    it "DMs the operator a success ack" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id,
        text: a_string_including("Черновик #").and(including("импортировано 1/1"))
      )
    end
  end
end
