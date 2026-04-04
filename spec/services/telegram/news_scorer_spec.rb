require "rails_helper"

RSpec.describe Telegram::NewsScorer do
  describe ".call" do
    subject(:score) { described_class.call(parsed_result) }

    let(:parsed_result) do
      Telegram::MessageParser::Result.new(
        text: text,
        html_content: "",
        from_id: 42,
        from_username: "testuser",
        from_first_name: "Denis",
        chat_id: 42,
        photo_file_id: nil,
        raw_text_length: raw_text.length,
        entities: entities,
        raw_text: raw_text
      )
    end

    let(:text) { "Some news article text" }
    let(:raw_text) { text }
    let(:entities) { [] }

    context "with no entities" do
      it "returns zero" do
        expect(score).to eq(0)
      end
    end

    context "with formatting entities" do
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 4 },
          { "type" => "italic", "offset" => 5, "length" => 3 }
        ]
      end

      it "adds points per formatting entity" do
        expect(score).to eq(2 * described_class::FORMATTING_POINTS)
      end
    end

    context "with non-formatting entities" do
      let(:entities) do
        [
          { "type" => "mention", "offset" => 0, "length" => 5 },
          { "type" => "hashtag", "offset" => 6, "length" => 4 },
          { "type" => "url", "offset" => 11, "length" => 20 }
        ]
      end

      it "does not score non-formatting entities" do
        expect(score).to eq(0)
      end
    end

    context "with mixed entity types" do
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 4 },
          { "type" => "mention", "offset" => 5, "length" => 5 },
          { "type" => "pre", "offset" => 11, "length" => 10 }
        ]
      end

      it "scores only formatting entities" do
        expect(score).to eq(2 * described_class::FORMATTING_POINTS)
      end
    end

    context "with formatting entities exceeding the cap" do
      let(:entities) do
        20.times.map do |i|
          { "type" => "bold", "offset" => i * 5, "length" => 4 }
        end
      end

      it "caps the formatting score" do
        expect(score).to eq(described_class::FORMATTING_CAP)
      end
    end

    context "with all formatting entity types" do
      let(:entities) do
        %w[bold italic code pre strikethrough].map.with_index do |type, i|
          { "type" => type, "offset" => i * 5, "length" => 4 }
        end
      end

      it "counts all formatting types" do
        expect(score).to eq(5 * described_class::FORMATTING_POINTS)
      end
    end

    context "with paragraph breaks" do
      let(:raw_text) { "First paragraph.\n\nSecond paragraph.\n\nThird paragraph." }

      it "adds points per paragraph break" do
        expect(score).to eq(2 * described_class::PARAGRAPH_POINTS)
      end
    end

    context "with single newlines only" do
      let(:raw_text) { "Line one.\nLine two.\nLine three." }

      it "does not score single newlines" do
        expect(score).to eq(0)
      end
    end

    context "with paragraph breaks exceeding the cap" do
      let(:raw_text) { ([ "Paragraph" ] * 15).join("\n\n") }

      it "caps the paragraph score" do
        expect(score).to eq(described_class::PARAGRAPH_CAP)
      end
    end

    context "with formatting entities and paragraph breaks" do
      let(:raw_text) { "Bold heading\n\nSome body text." }
      let(:entities) do
        [ { "type" => "bold", "offset" => 0, "length" => 12 } ]
      end

      it "sums both signals" do
        expected = described_class::FORMATTING_POINTS + described_class::PARAGRAPH_POINTS
        expect(score).to eq(expected)
      end
    end

    context "with text_link entities" do
      let(:entities) do
        [
          { "type" => "text_link", "offset" => 0, "length" => 10, "url" => "https://example.com" },
          { "type" => "text_link", "offset" => 20, "length" => 8, "url" => "https://example.org" }
        ]
      end

      it "adds points per link" do
        expect(score).to eq(2 * described_class::LINK_POINTS)
      end
    end

    context "with url entities" do
      let(:entities) do
        [
          { "type" => "url", "offset" => 0, "length" => 20 }
        ]
      end

      it "does not score plain url entities" do
        expect(score).to eq(0)
      end
    end

    context "with links exceeding the cap" do
      let(:entities) do
        15.times.map do |i|
          { "type" => "text_link", "offset" => i * 15, "length" => 10, "url" => "https://example.com/#{i}" }
        end
      end

      it "caps the link score" do
        expect(score).to eq(described_class::LINK_CAP)
      end
    end

    context "with links and formatting entities" do
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 4 },
          { "type" => "text_link", "offset" => 5, "length" => 10, "url" => "https://example.com" }
        ]
      end

      it "sums both signals" do
        expected = described_class::FORMATTING_POINTS + described_class::LINK_POINTS
        expect(score).to eq(expected)
      end
    end

    context "with a photo attached" do
      let(:parsed_result) do
        Telegram::MessageParser::Result.new(
          text: text,
          html_content: "",
          from_id: 42,
          from_username: "testuser",
          from_first_name: "Denis",
          chat_id: 42,
          photo_file_id: "some_photo_id",
          raw_text_length: raw_text.length,
          entities: entities,
          raw_text: raw_text
        )
      end

      it "adds photo bonus points" do
        expect(score).to eq(described_class::PHOTO_POINTS)
      end
    end

    context "without a photo" do
      it "does not add photo points" do
        expect(score).to eq(0)
      end
    end

    context "with matching keywords" do
      let(:raw_text) { "Результаты игра в третьем сезоне на турнире" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = true
          ft.value = "игра,сезон,турнир"
          ft.description = "Keywords for news scoring"
        end
      end

      it "adds points per matched keyword" do
        expect(score).to eq(3 * described_class::KEYWORD_POINTS)
      end
    end

    context "with duplicate keyword matches in text" do
      let(:raw_text) { "Игра за игрой, игра продолжается" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = true
          ft.value = "игра"
          ft.description = "Keywords for news scoring"
        end
      end

      it "counts each keyword only once" do
        expect(score).to eq(described_class::KEYWORD_POINTS)
      end
    end

    context "with keywords exceeding the cap" do
      let(:raw_text) { "игра сезон турнир рейтинг мафия ведущий тур результат протокол финал" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = true
          ft.value = "игра,сезон,турнир,рейтинг,мафия,ведущий,тур,результат,протокол,финал"
          ft.description = "Keywords for news scoring"
        end
      end

      it "caps the keyword score" do
        expect(score).to eq(described_class::KEYWORD_CAP)
      end
    end

    context "with no keywords configured" do
      before do
        FeatureToggle.find_by(key: "news_score_keywords")&.destroy
      end

      it "returns zero keyword score" do
        expect(score).to eq(0)
      end
    end

    context "with spaces around keywords in setting" do
      let(:raw_text) { "Результаты игра в сезоне" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = true
          ft.value = " игра , сезон "
          ft.description = "Keywords for news scoring"
        end
      end

      it "strips whitespace and matches" do
        expect(score).to eq(2 * described_class::KEYWORD_POINTS)
      end
    end

    context "with keywords in different case" do
      let(:raw_text) { "ИГРА в этом СЕЗОНЕ" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = true
          ft.value = "игра,сезон"
          ft.description = "Keywords for news scoring"
        end
      end

      it "matches case-insensitively" do
        expect(score).to eq(2 * described_class::KEYWORD_POINTS)
      end
    end

    context "with enabled toggle but empty value" do
      let(:raw_text) { "Результаты игра в сезоне" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = true
          ft.value = ""
          ft.description = "Keywords for news scoring"
        end
      end

      it "returns zero keyword score" do
        expect(score).to eq(0)
      end
    end

    context "with keywords toggle disabled" do
      let(:raw_text) { "Результаты игры третьего сезона" }

      before do
        FeatureToggle.find_or_create_by!(key: "news_score_keywords") do |ft|
          ft.enabled = false
          ft.value = "игра,сезон"
          ft.description = "Keywords for news scoring"
        end
      end

      it "returns zero keyword score" do
        expect(score).to eq(0)
      end
    end

    context "with high first-person pronoun ratio" do
      let(:raw_text) { "Я пошёл на игру и мне очень понравилось. Я думаю что мой уровень вырос. Меня это радует." }

      it "applies the penalty" do
        expect(score).to eq(described_class::FIRST_PERSON_PENALTY)
      end
    end

    context "with uppercase first-person pronouns" do
      let(:raw_text) { "Я написал. Я сделал. Я решил. Я понял. Мне нравится." }

      it "matches case-insensitively" do
        expect(score).to eq(described_class::FIRST_PERSON_PENALTY)
      end
    end

    context "with low first-person pronoun ratio" do
      let(:raw_text) { "Турнир завершился победой команды Альфа. Участники показали отличную игру. Результаты опубликованы на сайте клуба." }

      it "does not apply a penalty" do
        expect(score).to eq(0)
      end
    end

    context "with first-person pronouns below threshold" do
      let(:raw_text) { "Обзор сезона показал интересные результаты. Я считаю что команда выступила достойно. Все участники заслужили уважение за проявленный характер." }

      it "does not penalize when ratio is below threshold" do
        expect(score).to eq(0)
      end
    end

    context "with penalty combined with positive signals" do
      let(:raw_text) { "Я написал обзор.\n\nЯ думаю мне понравилось. Я считаю мой уровень вырос. Меня это радует." }
      let(:entities) do
        [ { "type" => "bold", "offset" => 0, "length" => 2 } ]
      end

      it "reduces total score but does not go below penalty floor" do
        positive = described_class::FORMATTING_POINTS + described_class::PARAGRAPH_POINTS
        expect(score).to be < positive
      end
    end

    context "with high question density" do
      let(:raw_text) { "Кто играл? Что случилось? Когда начало? Где проходит?" }

      it "applies the question penalty" do
        expect(score).to eq(described_class::QUESTION_PENALTY)
      end
    end

    context "with low question density" do
      let(:raw_text) { "Турнир завершился. Победила команда Альфа. Результаты опубликованы. Где посмотреть?" }

      it "does not penalize" do
        expect(score).to eq(0)
      end
    end

    context "with question ratio exactly at threshold" do
      let(:raw_text) { "Кто победил? Результаты опубликованы." }

      it "applies penalty at exactly 50% ratio" do
        expect(score).to eq(described_class::QUESTION_PENALTY)
      end
    end

    context "with question ratio just below threshold" do
      let(:raw_text) { "Кто победил? Результаты опубликованы. Все довольны." }

      it "does not penalize below 50%" do
        expect(score).to eq(0)
      end
    end

    context "with no questions" do
      let(:raw_text) { "Турнир завершился победой команды Альфа. Результаты опубликованы на сайте." }

      it "does not penalize" do
        expect(score).to eq(0)
      end
    end

    context "logging" do
      let(:raw_text) { "Bold heading\n\nSome body text." }
      let(:entities) do
        [ { "type" => "bold", "offset" => 0, "length" => 12 } ]
      end

      it "logs the score breakdown at debug level" do
        allow(Rails.logger).to receive(:debug)
        described_class.call(parsed_result)
        expect(Rails.logger).to have_received(:debug).with(
          /NewsScorer.*formatting=2.*paragraph=3.*link=0.*photo=0.*keyword=0.*first_person=0.*question=0.*total=5/
        )
      end
    end

    context "with questions and positive signals" do
      let(:raw_text) { "Кто победил? Что думаете? Как оценить?\n\nОбзор сезона." }
      let(:entities) do
        [ { "type" => "bold", "offset" => 0, "length" => 3 } ]
      end

      it "sums penalty with positive signals" do
        expected = described_class::FORMATTING_POINTS + described_class::PARAGRAPH_POINTS + described_class::QUESTION_PENALTY
        expect(score).to eq(expected)
      end
    end
  end
end
