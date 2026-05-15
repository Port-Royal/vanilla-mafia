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

  describe ".call (range)" do
    let(:parsed_link) do
      Telegram::MessageLinkParser::Result.new(
        source_chat: source_chat, message_id: start_message_id, count: 2
      )
    end

    let(:msg_a) { build_forwarded("AAA", 99999, message_id: 9001, date: 1_710_000_000) }
    let(:msg_b) { build_forwarded("BBB", 99999, message_id: 9002, date: 1_710_000_010) }
    let(:msg_c) { build_forwarded("CCC", 99999, message_id: 9003, date: 1_710_000_020) }

    def build_forwarded(text, sender_id, message_id:, date:)
      {
        "message_id" => message_id,
        "from" => { "id" => 0, "is_bot" => true },
        "text" => text,
        "forward_origin" => {
          "type" => "user",
          "sender_user" => { "id" => sender_id, "first_name" => "S" },
          "date" => date
        }
      }
    end

    before do
      allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
        payload =
          case message_id
          when 100 then msg_a
          when 101 then msg_b
          when 102 then msg_c
          end
        Telegram::ForwardMessageService::Result.new(success: payload.present?, message: payload, error_code: nil, description: nil)
      end
    end

    it "creates one consolidated draft" do
      expect {
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      }.to change(News, :count).by(1)
    end

    it "concatenates message text in order" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      body = News.last.content.body.to_plain_text
      expect(body.index("AAA")).to be < body.index("BBB")
      expect(body.index("BBB")).to be < body.index("CCC")
    end

    it "uses the first message's date for telegram_thread_started_at" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.telegram_thread_started_at).to eq(Time.at(1_710_000_000))
    end

    it "uses the last message's date for telegram_thread_last_message_at" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.telegram_thread_last_message_at).to eq(Time.at(1_710_000_020))
    end

    it "ack reports 3/3" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: a_string_including("3/3")
      )
    end

    context "with gaps (deleted middle message returns 404)" do
      before do
        allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
          case message_id
          when 100
            Telegram::ForwardMessageService::Result.new(success: true, message: msg_a, error_code: nil, description: nil)
          when 101
            Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 400, description: "message not found")
          when 102
            Telegram::ForwardMessageService::Result.new(success: true, message: msg_c, error_code: nil, description: nil)
          end
        end
      end

      it "skips the gap and imports the rest" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        body = News.last.content.body.to_plain_text
        expect(body).to include("AAA").and include("CCC")
        expect(body).not_to include("BBB")
      end

      it "ack reports 2/2 (only successful forwards count)" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: a_string_including("2/2")
        )
      end
    end

    context "with an inline photo in a range message" do
      let(:photo_message) do
        {
          "message_id" => 9002,
          "from" => { "id" => 0, "is_bot" => true },
          "caption" => "with photo",
          "photo" => [
            { "file_id" => "small_id", "file_size" => 100, "width" => 90, "height" => 90 },
            { "file_id" => "large_id", "file_size" => 5000, "width" => 800, "height" => 800 }
          ],
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_010
          }
        }
      end

      let(:download_result) do
        Telegram::DownloadFileService::SuccessResult.new(
          io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg"
        )
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(download_result)
        allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
          payload =
            case message_id
            when 100 then msg_a
            when 101 then photo_message
            when 102 then msg_c
            end
          Telegram::ForwardMessageService::Result.new(success: payload.present?, message: payload, error_code: nil, description: nil)
        end
      end

      it "downloads the largest photo" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::DownloadFileService).to have_received(:call).with("large_id")
      end

      it "embeds the photo inline in the draft body" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.content.body.to_html).to include("action-text-attachment")
      end

      it "does not attach photos to the gallery" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.photos).not_to be_attached
      end
    end
  end
end
