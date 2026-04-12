module Sluggable
  extend ActiveSupport::Concern

  TAIL_BYTES = 2 # => 4 hex characters
  MAX_SLUG_ATTEMPTS = 10

  class_methods do
    attr_reader :slug_source_attribute, :slug_source_condition

    def slug_source(attribute, if: nil)
      @slug_source_attribute = attribute
      @slug_source_condition = binding.local_variable_get(:if)
    end
  end

  included do
    validates :slug, uniqueness: true, allow_nil: true
    validates :slug, presence: true, if: :slug_required?
    before_validation :generate_slug, if: :should_generate_slug?
  end

  def to_param
    slug
  end

  private

  def slug_required?
    condition = self.class.slug_source_condition
    condition.nil? || instance_exec(&condition)
  end

  def should_generate_slug?
    return false if slug.present?

    slug_required?
  end

  def generate_slug
    base = slug_base
    candidate = base
    MAX_SLUG_ATTEMPTS.times do
      unless self.class.where.not(id: id).exists?(slug: candidate)
        self.slug = candidate
        return
      end
      candidate = "#{base}-#{SecureRandom.hex(TAIL_BYTES)}"
    end
    self.slug = candidate
  end

  def slug_base
    raw = public_send(self.class.slug_source_attribute).to_s
    CyrillicTransliterator.call(raw).parameterize.presence ||
      SecureRandom.hex(Sluggable::TAIL_BYTES)
  end
end
