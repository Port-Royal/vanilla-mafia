require "rails_helper"

RSpec.describe ProcessTelegramWebhookJob do
  let_it_be(:user) { create(:user) }
  let_it_be(:telegram_author) { create(:telegram_author, telegram_user_id: 12345, user: user) }

  let(:payload) do
    {
      "update_id" => 1,
      "message" => {
        "text" => "#news Breaking: tournament results announced",
        "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
        "chat" => { "id" => -100123 },
        "date" => 1710000000
      }
    }
  end

  describe "#perform" do
    context "when message has news tag and sender is whitelisted" do
      it "creates a draft news article" do
        expect { described_class.new.perform(payload) }.to change(News, :count).by(1)
      end

      it "sets the news title from the message text" do
        described_class.new.perform(payload)
        news = News.last
        expect(news.title).to eq("Breaking: tournament results announced")
      end

      it "sets the news content as formatted HTML" do
        described_class.new.perform(payload)
        news = News.last
        expect(news.content.body.to_plain_text).to eq("Breaking: tournament results announced")
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
            "caption" => "#news Photo news",
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
            "caption" => "#news Photo news",
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

    context "when message has news tag but sender is not whitelisted" do
      let(:payload) do
        {
          "update_id" => 2,
          "message" => {
            "text" => "#news Some news",
            "from" => { "id" => 99999, "username" => "stranger", "first_name" => "Bob" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when sender is whitelisted but message has no news tag" do
      let(:payload) do
        {
          "update_id" => 3,
          "message" => {
            "text" => "Just a regular message",
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
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
            "text" => "#news Orphan news",
            "from" => { "id" => 55555, "username" => "orphan", "first_name" => "Nobody" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when message text is only the news tag" do
      let(:payload) do
        {
          "update_id" => 7,
          "message" => {
            "text" => "#news",
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "does not create a news article" do
        expect { described_class.new.perform(payload) }.not_to change(News, :count)
      end
    end

    context "when message text is news tag with only whitespace" do
      let(:payload) do
        {
          "update_id" => 8,
          "message" => {
            "text" => "#news   ",
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
      let(:payload) do
        {
          "update_id" => 10,
          "message" => {
            "text" => "#news Bold announcement here",
            "entities" => [
              { "type" => "hashtag", "offset" => 0, "length" => 5 },
              { "type" => "bold", "offset" => 6, "length" => 4 }
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
        expect(News.last.title).to eq("Bold announcement here")
      end
    end

    context "when message title would be too long" do
      let(:payload) do
        {
          "update_id" => 6,
          "message" => {
            "text" => "#news " + "A" * 300,
            "from" => { "id" => 12345, "username" => "reporter", "first_name" => "Alex" },
            "chat" => { "id" => -100123 }
          }
        }
      end

      it "truncates the title to 255 characters" do
        described_class.new.perform(payload)
        expect(News.last.title.length).to be <= 255
      end
    end
  end
end
