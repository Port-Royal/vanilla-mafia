class PasswordStrengthValidator < ActiveModel::EachValidator
  COMMON_PASSWORDS = Set.new(%w[
    password password1 password12 password123 password1234
    qwerty qwerty123 qwertyuiop
    letmein welcome monkey dragon master
    login admin administrator
    abc123 iloveyou trustno1 sunshine
    football baseball soccer hockey
    shadow michael jennifer
  ]).freeze

  MINIMUM_CHARACTER_TYPES = 3

  def validate_each(record, attribute, value)
    return if value.blank?

    check_character_diversity(record, attribute, value)
    check_common_password(record, attribute, value)
  end

  private

  def check_character_diversity(record, attribute, value)
    types = 0
    types += 1 if value.match?(/[a-z]/)
    types += 1 if value.match?(/[A-Z]/)
    types += 1 if value.match?(/\d/)
    types += 1 if value.match?(/[^a-zA-Z\d]/)

    return if types >= MINIMUM_CHARACTER_TYPES

    record.errors.add(attribute, :insufficient_diversity)
  end

  def check_common_password(record, attribute, value)
    normalized = value.downcase.gsub(/[^a-z]/, "")

    return unless COMMON_PASSWORDS.include?(normalized)

    record.errors.add(attribute, :common_password)
  end
end
