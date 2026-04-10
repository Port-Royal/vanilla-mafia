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

    context "when telegram author has no linked user" do
      let_it_be(:unlinked_author) { create(:telegram_author, telegram_user_id: 55555, user: nil) }

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

      it "logs the rejection at debug level" do
        allow(Rails.logger).to receive(:debug)
        described_class.new.perform(payload)
        expect(Rails.logger).to have_received(:debug).with(/rejected.*score=0.*threshold=10.*from_id=12345/)
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

      it "logs the acceptance at info level" do
        allow(Rails.logger).to receive(:info)
        described_class.new.perform(payload)
        expect(Rails.logger).to have_received(:info).with(/accepted.*score=10.*threshold=10.*from_id=12345/)
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
  end
end
