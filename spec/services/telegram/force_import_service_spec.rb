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

    context "when the message has an empty text string but a caption" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "",
          "caption" => "caption headline",
          "photo" => [ { "file_id" => "cap_id", "file_size" => 10, "width" => 5, "height" => 5 } ],
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_000
          }
        }
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(
          Telegram::DownloadFileService::SuccessResult.new(
            io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg"
          )
        )
      end

      it "treats the blank text as absent and falls back to the caption for the title" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.title).to eq("caption headline")
      end

      it "includes the caption text in the draft body" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.content.body.to_plain_text).to include("caption headline")
      end
    end

    context "when the message has blank text and a blank caption (photo only)" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "",
          "caption" => "",
          "photo" => [ { "file_id" => "photo_id", "file_size" => 10, "width" => 5, "height" => 5 } ],
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_000
          }
        }
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(
          Telegram::DownloadFileService::SuccessResult.new(
            io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg"
          )
        )
      end

      it "uses the photo-only placeholder title" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.title).to eq("[медиа]")
      end
    end

    context "when a photo message has no caption key at all" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "photo" => [ { "file_id" => "nokey_id", "file_size" => 10, "width" => 5, "height" => 5 } ],
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_000
          }
        }
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(
          Telegram::DownloadFileService::SuccessResult.new(
            io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg"
          )
        )
      end

      it "uses the photo-only placeholder title without raising on the missing caption" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.title).to eq("[медиа]")
      end
    end

    context "when the message text carries formatting entities" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "Hello bold world",
          "entities" => [ { "type" => "bold", "offset" => 6, "length" => 4 } ],
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_000
          }
        }
      end

      it "applies the entities when rendering the draft body" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.content.body.to_html).to include("<strong>bold</strong>")
      end
    end

    context "when a photo message carries caption_entities" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "caption" => "Hello bold world",
          "caption_entities" => [ { "type" => "bold", "offset" => 6, "length" => 4 } ],
          "photo" => [ { "file_id" => "ce_id", "file_size" => 10, "width" => 5, "height" => 5 } ],
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_000
          }
        }
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(
          Telegram::DownloadFileService::SuccessResult.new(
            io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg"
          )
        )
      end

      it "applies caption_entities when rendering the caption" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.content.body.to_html).to include("<strong>bold</strong>")
      end
    end

    context "when a message has no photo" do
      it "does not embed any photo attachment in the body" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.content.body.to_html).not_to include("action-text-attachment")
      end
    end

    context "when the message text exceeds the title length limit" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "B" * 400,
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" },
            "date" => 1_710_000_000
          }
        }
      end

      it "truncates the title to 255 characters" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.title.length).to eq(255)
      end
    end

    context "when the forwarded message has no origin date" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "no date here",
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 99999, "first_name" => "S" }
          }
        }
      end

      it "falls back to the current time for created_at" do
        freeze_time do
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
          expect(News.last.created_at).to eq(Time.current)
        end
      end

      it "falls back to the current time for the thread timestamps" do
        freeze_time do
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
          news = News.last
          expect(news.telegram_thread_started_at).to eq(Time.current)
          expect(news.telegram_thread_last_message_at).to eq(Time.current)
        end
      end
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

    context "when the message uses the legacy forward_from / forward_date format" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "legacy forward",
          "forward_from" => { "id" => 99999, "first_name" => "Legacy" },
          "forward_date" => 1_710_000_500
        }
      end

      it "resolves the sender from forward_from.id" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.author).to eq(sender_user)
      end

      it "dates the draft from forward_date" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.created_at).to eq(Time.at(1_710_000_500))
      end
    end

    context "when forward_origin is present but its sender_user is not a hash" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "hidden sender",
          "forward_origin" => { "type" => "hidden_user", "sender_user_name" => "Anon", "date" => 1_710_000_600 },
          "forward_from" => { "id" => 99999, "first_name" => "Fallback" }
        }
      end

      it "falls back to forward_from for the sender" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.author).to eq(sender_user)
      end

      it "still dates the draft from forward_origin.date" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.created_at).to eq(Time.at(1_710_000_600))
      end
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

    context "when the last message in the range has no origin date" do
      let(:msg_c) do
        {
          "message_id" => 9003,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "CCC",
          "forward_origin" => { "type" => "user", "sender_user" => { "id" => 99999, "first_name" => "S" } }
        }
      end

      it "falls back to the first message's date for telegram_thread_last_message_at" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.telegram_thread_last_message_at).to eq(Time.at(1_710_000_000))
      end
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

    context "when one message in the range returns 403 but others succeed" do
      before do
        allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
          case message_id
          when 100, 102
            payload = message_id == 100 ? msg_a : msg_c
            Telegram::ForwardMessageService::Result.new(success: true, message: payload, error_code: nil, description: nil)
          when 101
            Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 403, description: "Forbidden")
          end
        end
      end

      it "still imports a draft (does not abort with 'no access')" do
        expect {
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        }.to change(News, :count).by(1)
      end

      it "does not DM the 'no access' text" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).not_to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_access")
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
            { "file_id" => "large_id", "file_size" => 5000, "width" => 800, "height" => 800 },
            { "file_id" => "medium_id", "file_size" => 800, "width" => 300, "height" => 300 }
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

      it "embeds the rendered attachment HTML (not the raw attachment object)" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.content.body.to_html).to include("<action-text-attachment")
      end

      context "when the photo download fails" do
        before do
          allow(Telegram::DownloadFileService).to receive(:call).and_return(
            Telegram::DownloadFileService::FailureResult.new(description: "download boom")
          )
        end

        it "still imports the draft without an inline attachment" do
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
          expect(News.last.content.body.to_html).not_to include("action-text-attachment")
        end

        it "still includes the surrounding text content" do
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
          body = News.last.content.body.to_plain_text
          expect(body).to include("AAA").and include("CCC")
        end
      end
    end

    context "with messages from different senders inside the range" do
      let(:msg_b_other) { build_forwarded("BBB", 88888, message_id: 9002, date: 1_710_000_010) }

      before do
        allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
          payload =
            case message_id
            when 100 then msg_a
            when 101 then msg_b_other
            when 102 then msg_c
            end
          Telegram::ForwardMessageService::Result.new(success: true, message: payload, error_code: nil, description: nil)
        end
      end

      it "includes only same-sender messages in the draft body" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        body = News.last.content.body.to_plain_text
        expect(body).to include("AAA").and include("CCC")
        expect(body).not_to include("BBB")
      end

      it "ack reports skipped count" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: a_string_including("2/3").and(including("1"))
        )
      end
    end
  end

  describe ".call (author resolution)" do
    before do
      allow(Telegram::ForwardMessageService).to receive(:call).and_return(
        Telegram::ForwardMessageService::Result.new(success: true, message: single_message_payload, error_code: nil, description: nil)
      )
      allow(Telegram::BotDmService).to receive(:call).and_return(true)
      allow(AutolinkPlayersInNewsService).to receive(:call)
      allow(NotifyEditorsAboutDraftService).to receive(:call)
      FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
        ft.enabled = true
        ft.value = ""
        ft.description = "force_import"
      end
    end

    context "when sender has a TelegramAuthor with a linked user" do
      it "authors as that linked user" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.author).to eq(sender_user)
      end

      it "does not DM a no-author warning when the author resolved cleanly" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).not_to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_author")
        )
      end
    end

    context "when sender has a TelegramAuthor with no user but a player (vm-196 stub path)" do
      let_it_be(:player) { create(:player) }
      let_it_be(:stub_author) { create(:telegram_author, telegram_user_id: 77777, user: nil, player: player) }

      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "stub me",
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 77777, "first_name" => "Stub" },
            "date" => 1_710_000_000
          }
        }
      end

      it "authors with a stub user linked to the player" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.author).to be_telegram_stub
        expect(News.last.author.player).to eq(player)
      end
    end

    context "when sender has no TelegramAuthor row" do
      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "stranger",
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 11111, "first_name" => "Stranger" },
            "date" => 1_710_000_000
          }
        }
      end

      it "authors as the operator" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.author).to eq(operator_user)
      end

      it "DMs a warning to the operator" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: a_string_including("Автор сообщения не привязан")
        )
      end
    end

    context "when sender has a TelegramAuthor row but no user and no player" do
      let_it_be(:orphan_author) { create(:telegram_author, telegram_user_id: 22222, user: nil, player: nil) }

      let(:single_message_payload) do
        {
          "message_id" => 9001,
          "from" => { "id" => 0, "is_bot" => true },
          "text" => "orphan",
          "forward_origin" => {
            "type" => "user",
            "sender_user" => { "id" => 22222, "first_name" => "Orphan" },
            "date" => 1_710_000_000
          }
        }
      end

      it "falls back to the operator as author" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.author).to eq(operator_user)
      end

      it "DMs a warning" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: a_string_including("Автор сообщения не привязан")
        )
      end
    end
  end

  describe ".call (errors)" do
    before do
      allow(Telegram::BotDmService).to receive(:call).and_return(true)
      allow(AutolinkPlayersInNewsService).to receive(:call)
      allow(NotifyEditorsAboutDraftService).to receive(:call)
    end

    context "when the feature toggle is disabled" do
      before do
        toggle = FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
          ft.enabled = false
          ft.value = ""
          ft.description = "force_import"
        end
        toggle.update!(enabled: false)
      end

      it "does not create a draft" do
        expect {
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        }.not_to change(News, :count)
      end

      it "DMs 'disabled'" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.disabled")
        )
      end

      it "does not call ForwardMessageService" do
        allow(Telegram::ForwardMessageService).to receive(:call)
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::ForwardMessageService).not_to have_received(:call)
      end
    end

    context "when count exceeds the max" do
      let(:parsed_link) do
        Telegram::MessageLinkParser::Result.new(source_chat: source_chat, message_id: start_message_id, count: 999)
      end

      before do
        FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "force_import"
        end
        FeatureToggle.find_or_create_by!(key: "telegram_force_import_max_range") do |ft|
          ft.enabled = true
          ft.value = "50"
          ft.description = "max_range"
        end
      end

      it "does not create a draft" do
        expect {
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        }.not_to change(News, :count)
      end

      it "DMs the count-too-large message with substituted limit and count" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: a_string_including("50").and(including("999"))
        )
      end
    end

    context "when ForwardMessageService returns 403 on every call" do
      before do
        FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "force_import"
        end
        allow(Telegram::ForwardMessageService).to receive(:call).and_return(
          Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 403, description: "Forbidden")
        )
      end

      it "DMs 'no access'" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_access")
        )
      end

      it "does not create a draft" do
        expect {
          described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        }.not_to change(News, :count)
      end

      it "does not also DM the 'no messages' text" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).not_to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_messages")
        )
      end
    end

    context "when some forwards fail with 400 and one with 403 (no successes)" do
      let(:parsed_link) do
        Telegram::MessageLinkParser::Result.new(
          source_chat: source_chat, message_id: start_message_id, count: 1
        )
      end

      before do
        FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "force_import"
        end
        allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
          code = message_id == start_message_id ? 400 : 403
          Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: code, description: "x")
        end
      end

      it "DMs 'no access' because at least one forward was forbidden" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_access")
        )
      end

      it "does not DM 'no messages'" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).not_to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_messages")
        )
      end
    end

    context "when ForwardMessageService returns only 400s" do
      before do
        FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "force_import"
        end
        allow(Telegram::ForwardMessageService).to receive(:call).and_return(
          Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 400, description: "not found")
        )
      end

      it "DMs 'no messages'" do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(Telegram::BotDmService).to have_received(:call).with(
          chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_messages")
        )
      end
    end
  end
end
