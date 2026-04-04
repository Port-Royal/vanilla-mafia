module Telegram
  class NewsScorer
    FORMATTING_TYPES = %w[bold italic code pre strikethrough].freeze
    FORMATTING_POINTS = 2
    FORMATTING_CAP = 20

    def self.call(parsed_result)
      new(parsed_result).call
    end

    def initialize(parsed_result)
      @parsed_result = parsed_result
    end

    def call
      formatting_score
    end

    private

    def formatting_score
      count = @parsed_result.entities.count { |e| FORMATTING_TYPES.include?(e["type"]) }
      [ count * FORMATTING_POINTS, FORMATTING_CAP ].min
    end
  end
end
