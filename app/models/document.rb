# A public club document, such as the league rules, written and published by admins in Avo.
class Document < ApplicationRecord
  include Sluggable
  slug_source :title

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  # Avo's own pages for this resource sit at these paths, so a document there could not be opened in the admin.
  RESERVED_SLUGS = %w[new edit].freeze

  has_rich_text :body

  normalizes :slug, with: ->(slug) { slug.strip.downcase }

  validates :title, presence: true
  validates :slug, format: { with: SLUG_FORMAT }, exclusion: { in: RESERVED_SLUGS }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }

  private

  # Sluggable keeps underscores, which SLUG_FORMAT rejects, and may land on a reserved slug.
  def slug_base
    base = super.tr("_", "-").parameterize.presence || SecureRandom.hex(Sluggable::TAIL_BYTES)
    RESERVED_SLUGS.include?(base) ? "#{base}-document" : base
  end
end
