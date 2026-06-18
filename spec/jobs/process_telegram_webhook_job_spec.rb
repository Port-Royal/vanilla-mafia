require "rails_helper"

RSpec.describe ProcessTelegramWebhookJob do
  let_it_be(:user) { create(:user) }
  let_it_be(:telegram_author) { create(:telegram_author, telegram_user_id: 12345, user: user) }

  let(:long_text) { "A" * 500 }

  let(:payload) do
    {
      "update_id" => 1,
      "message" => {
        "text" => long_text,
        "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
        "chat" => { "id" => -100123 },
        "date" => 1710000000
      }
    }
  end

  describe "#perform" do
    context "when sender is whitelisted and message is long enough" do
      it "creates a draft news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end

      it "sets the news title from the message text" do
        described_class.new.perform(payload)
        expect(News.last.title).to eq(long_text.truncate(255))
      end

      it "sets the news content as formatted HTML" do
        described_class.new.perform(payload)
        expect(News.last.content.body.to_plain_text).to eq(long_text)
      end

      it "sets the author to the linked user" do
        described_class.new.perform(payload)
        expect(News.last.author).to eq(user)
      end

      it "creates the news as a draft" do
        described_class.new.perform(payload)
        expect(News.last.status).to eq("draft")
      end

      it "does not call DownloadFileService" do
        allow(Telegram::DownloadFileService).to receive(:call)
        described_class.new.perform(payload)
        expect(Telegram::DownloadFileService).not_to have_received(:call)
      end
    end

    context "when message has a photo" do
      let(:payload) do
        {
          "update_id" => 1,
          "message" => {
            "photo" => [
              { "file_id" => "small_id", "file_size" => 1024, "width" => 90, "height" => 90 },
              { "file_id" => "large_id", "file_size" => 51200, "width" => 800, "height" => 800 }
            ],
            "caption" => long_text,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      let(:download_result) do
        Telegram::DownloadFileService::SuccessResult.new(
          io: StringIO.new("fake image"),
          filename: "photo.jpg",
          content_type: "image/jpeg"
        )
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(download_result)
      end

      it "creates a news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end

      it "downloads the largest photo" do
        described_class.new.perform(payload)
        expect(Telegram::DownloadFileService).to have_received(:call).with("large_id")
      end

      it "attaches the photo to the news article" do
        described_class.new.perform(payload)
        expect(News.last.photos).to be_attached
      end

      it "attaches the photo with correct filename" do
        described_class.new.perform(payload)
        expect(News.last.photos.first.filename.to_s).to eq("photo.jpg")
      end

      it "attaches the photo with correct content type" do
        described_class.new.perform(payload)
        expect(News.last.photos.first.content_type).to eq("image/jpeg")
      end
    end

    context "when photo download fails" do
      let(:payload) do
        {
          "update_id" => 1,
          "message" => {
            "photo" => [
              { "file_id" => "bad_id", "file_size" => 1024, "width" => 90, "height" => 90 }
            ],
            "caption" => long_text,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      let(:failure_result) do
        Telegram::DownloadFileService::FailureResult.new(description: "Download failed")
      end

      before do
        allow(Telegram::DownloadFileService).to receive(:call).and_return(failure_result)
      end

      it "still creates the news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end

      it "does not attach any photo" do
        described_class.new.perform(payload)
        expect(News.last.photos).not_to be_attached
      end
    end

    context "when sender is not whitelisted" do
      let(:payload) do
        {
          "update_id" => 2,
          "message" => {
            "text" => long_text,
            "from" => { "id" => 99999, "username" => "stranger", "first_name" => "Bob" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when message is shorter than 500 characters" do
      let(:payload) do
        {
          "update_id" => 3,
          "message" => {
            "text" => "A" * 499,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when message is exactly 500 characters" do
      let(:payload) do
        {
          "update_id" => 3,
          "message" => {
            "text" => "A" * 500,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      it "creates a news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end
    end

    context "when message is >= 500 raw characters but shorter after squish" do
      let(:text_with_newlines) { ("A" * 50 + "\n" * 10) * 9 }

      let(:payload) do
        {
          "update_id" => 3,
          "message" => {
            "text" => text_with_newlines,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      it "uses raw text length and creates a news article" do
        expect(text_with_newlines.strip.length).to be >= 500
        expect(text_with_newlines.squish.length).to be < 500
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end
    end

    context "when message is nil (no message or edited_message key)" do
      let(:payload) { { "update_id" => 4 } }

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when telegram author has no linked user and no player" do
      let_it_be(:unlinked_author) { create(:telegram_author, telegram_user_id: 55555, user: nil, player: nil) }

      let(:payload) do
        {
          "update_id" => 5,
          "message" => {
            "text" => long_text,
            "from" => { "id" => 55555, "username" => "orphan", "first_name" => "Nobody" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end

      it "logs the silent drop as structured JSON at warn level" do
        logged = nil
        allow(Rails.logger).to receive(:warn) { |msg| logged = msg }
        described_class.new.perform(payload)
        expect(JSON.parse(logged)).to eq(
          "event" => "telegram_webhook.no_linked_user",
          "from_id" => 55555,
          "telegram_author_id" => unlinked_author.id
        )
      end
    end

    context "when telegram author has a linked player but no user (stub path)" do
      let_it_be(:player) { create(:player) }
      let_it_be(:telegram_author_with_player) do
        create(:telegram_author, telegram_user_id: 77777, user: nil, player: player)
      end

      let(:payload) do
        {
          "update_id" => 9,
          "message" => {
            "text" => long_text,
            "from" => { "id" => 77777, "username" => "tg_only", "first_name" => "Player" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      it "creates a news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end

      it "authors the news with a stub user linked to the player" do
        described_class.new.perform(payload)
        expect(News.last.author.player).to eq(player)
      end

      it "marks the author as a telegram stub" do
        described_class.new.perform(payload)
        expect(News.last.author).to be_telegram_stub
      end

      it "caches the stub user on the telegram author" do
        described_class.new.perform(payload)
        expect(telegram_author_with_player.reload.user).to eq(News.last.author)
      end
    end

    context "when message text is blank" do
      let(:payload) do
        {
          "update_id" => 7,
          "message" => {
            "text" => "",
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when message text is only whitespace" do
      let(:payload) do
        {
          "update_id" => 8,
          "message" => {
            "text" => " " * 600,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when message has formatting entities" do
      let(:bold_text) { "Bold " + "x" * 495 }

      let(:payload) do
        {
          "update_id" => 10,
          "message" => {
            "text" => bold_text,
            "entities" => [
              { "type" => "bold", "offset" => 0, "length" => 4 }
            ],
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      it "stores formatted HTML in content" do
        described_class.new.perform(payload)
        expect(News.last.content.body.to_s).to include("<strong>Bold</strong>")
      end

      it "uses plain text for the title" do
        described_class.new.perform(payload)
        expect(News.last.title).to eq(bold_text.truncate(255))
      end
    end

    context "when message title would be too long" do
      let(:payload) do
        {
          "update_id" => 6,
          "message" => {
            "text" => "A" * 600,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 },
            "date" => 1710000000
          }
        }
      end

      it "truncates the title to 255 characters" do
        described_class.new.perform(payload)
        expect(News.last.title.length).to be <= 255
      end
    end

    context "when it creates a draft" do
      it "notifies editors" do
        allow(NotifyEditorsAboutDraftService).to receive(:call)
        described_class.new.perform(payload)
        expect(NotifyEditorsAboutDraftService).to have_received(:call).with(News.last)
      end

      it "runs the player autolink service on the created news" do
        allow(AutolinkPlayersInNewsService).to receive(:call)
        described_class.new.perform(payload)
        expect(AutolinkPlayersInNewsService).to have_received(:call).with(News.last)
      end
    end

    context "when news score is below threshold" do
      before do
        allow(Telegram::NewsScorer).to receive(:call).and_return(0)
        FeatureToggle.find_or_create_by!(key: "news_score_threshold") do |ft|
          ft.enabled = true
          ft.value = "10"
          ft.description = "Minimum news score"
        end
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end

      it "logs the rejection as structured JSON at debug level" do
        allow(Rails.logger).to receive(:debug)
        described_class.new.perform(payload)
        expect(Rails.logger).to have_received(:debug).with(
          a_string_matching(/"event":"telegram_webhook\.rejected".*"score":0.*"threshold":10.*"from_id":12345[,}]/)
        )
      end
    end

    context "when news score meets threshold" do
      before do
        allow(Telegram::NewsScorer).to receive(:call).and_return(10)
        FeatureToggle.find_or_create_by!(key: "news_score_threshold") do |ft|
          ft.enabled = true
          ft.value = "10"
          ft.description = "Minimum news score"
        end
      end

      it "creates a news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end

      it "passes the parsed result to the scorer" do
        described_class.new.perform(payload)
        expect(Telegram::NewsScorer).to have_received(:call).with(an_instance_of(Telegram::MessageParser::Result))
      end

      it "logs the acceptance as structured JSON at info level" do
        allow(Rails.logger).to receive(:info)
        described_class.new.perform(payload)
        expect(Rails.logger).to have_received(:info).with(
          a_string_matching(/"event":"telegram_webhook\.accepted".*"score":10.*"threshold":10.*"from_id":12345[,}]/)
        )
      end
    end

    context "when news score threshold has a custom value" do
      before do
        allow(Telegram::NewsScorer).to receive(:call).and_return(7)
        FeatureToggle.find_or_create_by!(key: "news_score_threshold") do |ft|
          ft.enabled = true
          ft.value = "5"
          ft.description = "Minimum news score"
        end
      end

      it "creates a news article when score meets the custom threshold" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end
    end

    context "when news score threshold toggle has blank value" do
      before do
        allow(Telegram::NewsScorer).to receive(:call).and_return(5)
        FeatureToggle.find_or_create_by!(key: "news_score_threshold") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "Minimum news score"
        end
      end

      it "uses the default threshold and does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when news score threshold toggle is disabled" do
      before do
        allow(Telegram::NewsScorer).to receive(:call).and_return(0)
        FeatureToggle.find_or_create_by!(key: "news_score_threshold") do |ft|
          ft.enabled = false
          ft.value = "10"
          ft.description = "Minimum news score"
        end
      end

      it "skips scoring and creates a news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
        expect(Telegram::NewsScorer).not_to have_received(:call)
      end
    end

    context "with thread-window feature toggle enabled" do
      def enable_thread_window(strategy: "sliding", seconds: 900)
        upsert_toggle("telegram_thread_window", enabled: true, value: "")
        upsert_toggle("telegram_thread_window_seconds", enabled: true, value: seconds.to_s)
        upsert_toggle("telegram_thread_window_strategy", enabled: true, value: strategy)
      end

      def upsert_toggle(key, enabled:, value:)
        toggle = FeatureToggle.find_or_initialize_by(key: key)
        toggle.assign_attributes(enabled: enabled, value: value, description: key)
        toggle.save!
      end

      def payload_with(text: long_text, from_id: 12345, update_id: 100, photo: nil, message_id: nil, chat_id: -1, edited: false)
        msg = { "from" => { "id" => from_id, "username" => "x", "first_name" => "X" }, "chat" => { "id" => chat_id }, "date" => 1710000000 }
        msg["text"] = text if text
        msg["photo"] = photo if photo
        msg["message_id"] = message_id if message_id
        { "update_id" => update_id, (edited ? "edited_message" : "message") => msg }
      end

      before { enable_thread_window }

      context "when no open thread exists" do
        it "creates a new draft and marks thread timestamps" do
          freeze_time do
            described_class.new.perform(payload_with(update_id: 200))
            news = News.last
            expect(news.telegram_thread_started_at).to eq(Time.current)
            expect(news.telegram_thread_last_message_at).to eq(Time.current)
          end
        end

        it "still enforces the MIN_TEXT_LENGTH gate for the opener" do
          expect {
            described_class.new.perform(payload_with(text: "short", update_id: 201))
          }.not_to change(News, :count)
        end

        it "records the telegram message key on the new draft" do
          described_class.new.perform(payload_with(update_id: 210, message_id: 555))
          expect(News.last.telegram_message_keys).to eq([ "-1:555" ])
        end
      end

      context "when an open thread exists for the same author" do
        let_it_be(:second_text) { "B" * 50 }

        let!(:thread_draft) do
          news = News.create!(
            title: "first",
            content: "<p>First message body</p>",
            author: user,
            status: :draft,
            telegram_thread_started_at: 2.minutes.ago,
            telegram_thread_last_message_at: 2.minutes.ago
          )
          news
        end

        it "appends the new text to the existing draft instead of creating one" do
          expect {
            described_class.new.perform(payload_with(text: second_text, update_id: 300))
          }.not_to change(News, :count)
          expect(thread_draft.reload.content.body.to_html).to include("First message body").and include(second_text)
        end

        it "updates telegram_thread_last_message_at to now" do
          freeze_time do
            described_class.new.perform(payload_with(text: second_text, update_id: 301))
            expect(thread_draft.reload.telegram_thread_last_message_at).to eq(Time.current)
          end
        end

        it "appends short text that would otherwise be rejected by MIN_TEXT_LENGTH" do
          described_class.new.perform(payload_with(text: "tiny", update_id: 302))
          expect(thread_draft.reload.content.body.to_plain_text).to include("tiny")
        end

        it "does not record a key when the message has no message_id" do
          described_class.new.perform(payload_with(text: "tiny", update_id: 306))
          expect(thread_draft.reload.telegram_message_keys).to eq([])
        end

        it "records the composite key when the appended message has a message_id" do
          described_class.new.perform(payload_with(text: "tiny", update_id: 307, message_id: 4242))
          expect(thread_draft.reload.telegram_message_keys).to eq([ "-1:4242" ])
        end

        it "re-runs the player autolink service on the updated draft" do
          allow(AutolinkPlayersInNewsService).to receive(:call)
          described_class.new.perform(payload_with(text: "tiny", update_id: 304))
          expect(AutolinkPlayersInNewsService).to have_received(:call).with(thread_draft)
        end

        it "does not re-notify editors about the existing draft" do
          allow(NotifyEditorsAboutDraftService).to receive(:call)
          described_class.new.perform(payload_with(text: "tiny", update_id: 305))
          expect(NotifyEditorsAboutDraftService).not_to have_received(:call)
        end

        it "embeds inline photos in body and does not attach to gallery" do
          download_result = Telegram::DownloadFileService::SuccessResult.new(
            io: StringIO.new("fake image"),
            filename: "p.jpg",
            content_type: "image/jpeg"
          )
          allow(Telegram::DownloadFileService).to receive(:call).and_return(download_result)

          described_class.new.perform(payload_with(
            text: nil,
            update_id: 303,
            photo: [ { "file_id" => "big", "file_size" => 100, "width" => 10, "height" => 10 } ]
          ))

          thread_draft.reload
          expect(thread_draft.content.body.to_html).to include("action-text-attachment")
          expect(thread_draft.photos).not_to be_attached
          expect(Telegram::DownloadFileService).to have_received(:call).with("big")
        end
      end

      context "when the same telegram message is delivered more than once" do
        let!(:thread_draft) do
          News.create!(
            title: "first",
            content: "<p>First message body</p>",
            author: user,
            status: :draft,
            telegram_thread_started_at: 1.minute.ago,
            telegram_thread_last_message_at: 1.minute.ago,
            telegram_message_keys: [ "-1:777" ]
          )
        end

        it "does not append a re-delivery of an already-imported message" do
          described_class.new.perform(payload_with(text: "B" * 50, update_id: 900, message_id: 777))
          expect(thread_draft.reload.content.body.to_plain_text).to eq("First message body")
        end

        it "does not append when the duplicate arrives as an edited_message" do
          described_class.new.perform(payload_with(text: "C" * 50, update_id: 901, message_id: 777, edited: true))
          expect(thread_draft.reload.content.body.to_plain_text).to eq("First message body")
        end

        it "does not bump telegram_thread_last_message_at for a duplicate" do
          freeze_time do
            original = thread_draft.telegram_thread_last_message_at
            described_class.new.perform(payload_with(text: "D" * 50, update_id: 902, message_id: 777))
            expect(thread_draft.reload.telegram_thread_last_message_at).to eq(original)
          end
        end

        it "does not re-run the autolink service for a duplicate" do
          allow(AutolinkPlayersInNewsService).to receive(:call)
          described_class.new.perform(payload_with(text: "D" * 50, update_id: 903, message_id: 777))
          expect(AutolinkPlayersInNewsService).not_to have_received(:call)
        end

        it "appends and records a distinct, not-yet-imported message" do
          described_class.new.perform(payload_with(text: "E" * 50, update_id: 904, message_id: 888))
          thread_draft.reload
          expect(thread_draft.content.body.to_plain_text).to include("E" * 50)
          expect(thread_draft.telegram_message_keys).to contain_exactly("-1:777", "-1:888")
        end

        it "appends a message that reuses the numeric id from a different chat" do
          described_class.new.perform(payload_with(text: "F" * 50, update_id: 905, message_id: 777, chat_id: -2))
          thread_draft.reload
          expect(thread_draft.content.body.to_plain_text).to include("F" * 50)
          expect(thread_draft.telegram_message_keys).to contain_exactly("-1:777", "-2:777")
        end
      end

      context "when the most recent thread is past the sliding window" do
        let!(:stale_draft) do
          News.create!(
            title: "old",
            content: "<p>old</p>",
            author: user,
            status: :draft,
            telegram_thread_started_at: 2.hours.ago,
            telegram_thread_last_message_at: 30.minutes.ago
          )
        end

        before { enable_thread_window(strategy: "sliding", seconds: 900) }

        it "creates a new draft and does not touch the stale one" do
          expect {
            described_class.new.perform(payload_with(update_id: 400))
          }.to change(News, :count).by(1)
          expect(stale_draft.reload.content.body.to_plain_text).to eq("old")
        end
      end

      context "with fixed-window strategy" do
        before { enable_thread_window(strategy: "fixed", seconds: 600) }

        context "when first message is within the fixed window" do
          let!(:thread_draft) do
            News.create!(
              title: "first",
              content: "<p>F</p>",
              author: user,
              status: :draft,
              telegram_thread_started_at: 5.minutes.ago,
              telegram_thread_last_message_at: 1.minute.ago
            )
          end

          it "appends to the thread" do
            expect {
              described_class.new.perform(payload_with(update_id: 500))
            }.not_to change(News, :count)
            expect(thread_draft.reload.content.body.to_html).to include("F")
          end
        end

        context "when first message is older than the fixed window" do
          let!(:thread_draft) do
            News.create!(
              title: "stale fixed",
              content: "<p>S</p>",
              author: user,
              status: :draft,
              telegram_thread_started_at: 20.minutes.ago,
              telegram_thread_last_message_at: 30.seconds.ago
            )
          end

          it "creates a new draft (fixed window does not extend with activity)" do
            expect {
              described_class.new.perform(payload_with(update_id: 501))
            }.to change(News, :count).by(1)
          end
        end
      end

      context "when threaded news belongs to a different author" do
        let_it_be(:other_user) { create(:user) }
        let!(:other_draft) do
          News.create!(
            title: "other",
            content: "<p>O</p>",
            author: other_user,
            status: :draft,
            telegram_thread_started_at: 1.minute.ago,
            telegram_thread_last_message_at: 1.minute.ago
          )
        end

        it "creates a new draft for the current author" do
          expect {
            described_class.new.perform(payload_with(update_id: 600))
          }.to change(News, :count).by(1)
          expect(News.last.author).to eq(user)
        end
      end

      context "when the only matching draft was already published" do
        let!(:published) do
          News.create!(
            title: "pub",
            content: "<p>P</p>",
            author: user,
            status: :published,
            published_at: Time.current,
            telegram_thread_started_at: 1.minute.ago,
            telegram_thread_last_message_at: 1.minute.ago
          )
        end

        it "creates a new draft and leaves the published article alone" do
          expect {
            described_class.new.perform(payload_with(update_id: 700))
          }.to change(News, :count).by(1)
          expect(published.reload.content.body.to_plain_text).to eq("P")
        end
      end
    end

    context "with a force-import DM" do
      let(:operator_id) { 12345 }
      let(:operator_chat_id) { 12345 }

      let(:dm_payload) do
        {
          "update_id" => 5000,
          "message" => {
            "text" => "https://t.me/c/1111111111/678",
            "from" => { "id" => operator_id, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => operator_chat_id, "type" => "private" },
            "date" => 1_710_000_000
          }
        }
      end

      before do
        FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "force_import"
        end
        allow(Telegram::ForceImportService).to receive(:call)
      end

      it "dispatches to ForceImportService" do
        described_class.new.perform(dm_payload)
        expect(Telegram::ForceImportService).to have_received(:call).with(
          parsed_link: an_instance_of(Telegram::MessageLinkParser::Result),
          operator_chat_id: operator_chat_id,
          operator_user: user
        )
      end

      it "does not run the normal news-draft pipeline" do
        expect { described_class.new.perform(dm_payload) }.not_to change(News, :count)
      end

      context "when DM text is not a recognized link" do
        let(:dm_payload) do
          {
            "update_id" => 5001,
            "message" => {
              "text" => "hello bot",
              "from" => { "id" => operator_id, "username" => "reporter", "first_name" => "Alex" },
              "chat" => { "id" => operator_chat_id, "type" => "private" },
              "date" => 1_710_000_000
            }
          }
        end

        it "DMs help text" do
          allow(Telegram::BotDmService).to receive(:call).and_return(true)
          described_class.new.perform(dm_payload)
          expect(Telegram::BotDmService).to have_received(:call).with(
            chat_id: operator_chat_id, text: I18n.t("telegram.force_import.bad_link")
          )
        end

        it "does not dispatch to ForceImportService" do
          described_class.new.perform(dm_payload)
          expect(Telegram::ForceImportService).not_to have_received(:call)
        end
      end

      context "when DM is from a non-whitelisted sender" do
        let(:dm_payload) do
          {
            "update_id" => 5002,
            "message" => {
              "text" => "https://t.me/c/1111111111/678",
              "from" => { "id" => 99999, "username" => "stranger", "first_name" => "Bob" },
              "chat" => { "id" => 99999, "type" => "private" },
              "date" => 1_710_000_000
            }
          }
        end

        it "does not dispatch to ForceImportService and does not create a draft" do
          expect { described_class.new.perform(dm_payload) }.not_to change(News, :count)
          expect(Telegram::ForceImportService).not_to have_received(:call)
        end
      end
    end

    context "with thread-window feature toggle disabled (default)" do
      it "creates a fresh draft on every qualifying message (no append)" do
        expect {
          2.times { |i|
            described_class.new.perform({
              "update_id" => 900 + i,
              "message" => {
                "text" => long_text,
                "from" => { "id" => 12345, "username" => "r", "first_name" => "A" },
                "chat" => { "id" => -1 },
                "date" => 1710000000
              }
            })
          }
        }.to change(News, :count).by(2)
      end
    end
  end

  describe "concurrency controls" do
    it "serializes jobs to one at a time per Telegram sender" do
      expect(described_class.concurrency_limit).to eq(1)
    end

    it "keys the concurrency lock on the sender's Telegram user id" do
      job = described_class.new(payload)
      expect(job.concurrency_key).to include("12345")
    end

    it "falls back to edited_message sender when message is absent" do
      edited_payload = {
        "update_id" => 2,
        "edited_message" => {
          "text" => long_text,
          "from" => { "id" => 99999, "username" => "reporter" },
          "chat" => { "id" => -100123 },
          "date" => 1710000000
        }
      }
      job = described_class.new(edited_payload)
      expect(job.concurrency_key).to include("99999")
    end
  end
end
