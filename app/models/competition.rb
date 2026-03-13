class Competition < ApplicationRecord
  KINDS = {
    season: "season", series: "series", minicup: "minicup",
    tournament: "tournament", round: "round", group: "group",
    fun_session: "fun_session"
  }.freeze

  enum :kind, KINDS, scopes: false

  belongs_to :parent, class_name: "Competition", optional: true
  has_many :children, class_name: "Competition", foreign_key: :parent_id, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :parent_is_not_self

  scope :featured, -> { where(featured: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :roots, -> { where(parent_id: nil) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.parameterize
  end

  def parent_is_not_self
    if parent_id.present? && parent_id == id
      errors.add(:parent_id, "cannot reference itself")
    end
  end
end
