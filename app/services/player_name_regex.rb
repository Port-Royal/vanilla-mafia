class PlayerNameRegex
  ADJ_FEMININE_ENDINGS = %w[ая яя ой ою ую ей].freeze
  ADJ_MASCULINE_ENDINGS = %w[ый ий ого его ому ему ым им ом ем].freeze
  ADJ_NEUTER_ENDINGS = %w[ое ее ого его ому ему ым им ом ем].freeze
  ADJ_PLURAL_ENDINGS = %w[ые ие ых их ым им ыми ими].freeze
  NOUN_PLURAL_ENDINGS = %w[и ы ов ев ей ам ям ами ями ах ях].freeze
  NOUN_MASC_CONSONANT_ENDINGS = [ "", "а", "у", "ом", "е", "ем" ].freeze
  NOUN_MASC_J_ENDINGS = %w[й я ю ем е].freeze
  NOUN_FEM_A_ENDINGS = %w[а ы и е у ой ей ою ею].freeze
  NOUN_FEM_YA_ENDINGS = %w[я и е ю ей ёй ею ёю].freeze
  NOUN_NEUTER_ENDINGS = %w[о е а я у ю ом ем].freeze

  ENDING_RULES = [
    [ %w[ая яя], 2, ADJ_FEMININE_ENDINGS ],
    [ %w[ый ий], 2, ADJ_MASCULINE_ENDINGS ],
    [ %w[ое ее], 2, ADJ_NEUTER_ENDINGS ],
    [ %w[ые ие], 2, ADJ_PLURAL_ENDINGS ],
    [ %w[и ы],   1, NOUN_PLURAL_ENDINGS ],
    [ %w[й],     1, NOUN_MASC_J_ENDINGS ],
    [ %w[а],     1, NOUN_FEM_A_ENDINGS ],
    [ %w[я],     1, NOUN_FEM_YA_ENDINGS ],
    [ %w[о е],   1, NOUN_NEUTER_ENDINGS ]
  ].freeze

  MIN_STEM_WORD_LENGTH = 3

  def self.build(name)
    parts = name.strip.split(/\s+/).map { |word| word_pattern(word) }
    Regexp.new("(?<!\\p{L})#{parts.join('\\s+')}(?!\\p{L})", Regexp::IGNORECASE)
  end

  def self.word_pattern(word)
    return Regexp.escape(word) unless cyrillic?(word)
    return Regexp.escape(word) if word.length < MIN_STEM_WORD_LENGTH

    stem, endings = stem_and_endings(word)
    "#{Regexp.escape(stem)}(?:#{endings.map { |e| Regexp.escape(e) }.join('|')})"
  end

  def self.cyrillic?(word)
    word.match?(/\p{Cyrillic}/)
  end

  def self.stem_and_endings(word)
    downcased = word.downcase
    ENDING_RULES.each do |suffixes, strip, endings|
      return [ word[0...-strip], endings ] if downcased.end_with?(*suffixes)
    end
    [ word, NOUN_MASC_CONSONANT_ENDINGS ]
  end
end
