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

      it "sets the news content from the message text" do
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
