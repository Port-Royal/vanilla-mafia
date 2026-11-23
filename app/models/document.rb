# A public club document, such as the league rules, written and published by admins in Avo.
class Document < ApplicationRecord
  include Sluggable
  slug_source :title

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  has_rich_text :body

  validates :title, presence: true
  validates :slug, format: { with: SLUG_FORMAT }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
end
