module Telegram
  class NewsScorer
    FORMATTING_TYPES = %w[bold italic code pre strikethrough].freeze
    FORMATTING_POINTS = 2
    FORMATTING_CAP = 20

    PARAGRAPH_POINTS = 3
    PARAGRAPH_CAP = 15

    LINK_POINTS = 3
    LINK_CAP = 15

    PHOTO_POINTS = 5

    KEYWORD_POINTS = 2
    KEYWORD_CAP = 10
    KEYWORD_SETTING = "news_score_keywords"

    FIRST_PERSON_PRONOUNS = %w[я мне мной меня мой моя моё мои моего моей моему моим моих моими].freeze
    FIRST_PERSON_THRESHOLD = 0.08
    FIRST_PERSON_PENALTY = -10

    def self.call(parsed_result)
      new(parsed_result).call
    end

    def initialize(parsed_result)
      @parsed_result = parsed_result
    end

    def call
      formatting_score + paragraph_score + link_score + photo_score + keyword_score + first_person_penalty
    end

    private

    def formatting_score
      count = @parsed_result.entities.count { |e| FORMATTING_TYPES.include?(e["type"]) }
      [ count * FORMATTING_POINTS, FORMATTING_CAP ].min
    end

    def paragraph_score
      count = @parsed_result.raw_text.scan("\n\n").size
      [ count * PARAGRAPH_POINTS, PARAGRAPH_CAP ].min
    end

    def link_score
      count = @parsed_result.entities.count { |e| e["type"] == "text_link" }
      [ count * LINK_POINTS, LINK_CAP ].min
    end

    def photo_score
      @parsed_result.photo_file_id.present? ? PHOTO_POINTS : 0
    end

    def first_person_penalty
      words = @parsed_result.raw_text.downcase.split(/\s+/)
      return 0 if words.empty?

      pronoun_count = words.count { |w| FIRST_PERSON_PRONOUNS.include?(w) }
      ratio = pronoun_count.to_f / words.size
      ratio > FIRST_PERSON_THRESHOLD ? FIRST_PERSON_PENALTY : 0
    end

    def keyword_score
      return 0 unless FeatureToggle.enabled?(KEYWORD_SETTING)

      keywords_csv = FeatureToggle.value_for(KEYWORD_SETTING, default: "")
      return 0 if keywords_csv.blank?

      keywords = keywords_csv.split(",").map(&:strip).reject(&:blank?)
      text_downcase = @parsed_result.raw_text.downcase
      count = keywords.count { |kw| text_downcase.include?(kw.downcase) }
      [ count * KEYWORD_POINTS, KEYWORD_CAP ].min
    end
  end
end
