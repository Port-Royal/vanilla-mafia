class Competition < ApplicationRecord
  KINDS = %w[season series minicup tournament round group fun_session].freeze

  belongs_to :parent, class_name: "Competition", optional: true
  has_many :children, class_name: "Competition", foreign_key: :parent_id, dependent: :destroy

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :slug, presence: true, uniqueness: true

  scope :featured, -> { where(featured: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :roots, -> { where(parent_id: nil) }
  scope :by_kind, ->(kind) { where(kind: kind) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
