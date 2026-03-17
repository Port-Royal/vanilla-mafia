class Competition < ApplicationRecord
  KINDS = {
    season: "season", series: "series", minicup: "minicup",
    tournament: "tournament", round: "round", group: "group",
    fun_session: "fun_session"
  }.freeze

  enum :kind, KINDS, scopes: false

  belongs_to :parent, class_name: "Competition", optional: true
  has_many :children, class_name: "Competition", foreign_key: :parent_id, dependent: :destroy
  has_many :games, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :parent_is_not_self

  scope :featured, -> { where(featured: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :roots, -> { where(parent_id: nil) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def to_param
    slug
  end

  def root
    node = self
    node = node.parent while node.parent
    node
  end

  def ancestors
    result = []
    node = self
    while node.parent
      node = node.parent
      result.unshift(node)
    end
    result
  end

  def subtree_ids
    self.class.connection.select_values(subtree_ids_sql)
  end

  private

  def subtree_ids_sql
    sanitized_id = self.class.connection.quote(id)
    <<~SQL
      WITH RECURSIVE subtree AS (
        SELECT id FROM competitions WHERE id = #{sanitized_id}
        UNION ALL
        SELECT c.id FROM competitions c
        INNER JOIN subtree s ON c.parent_id = s.id
      )
      SELECT id FROM subtree
    SQL
  end


  def generate_slug
    self.slug = name.parameterize
  end

  def parent_is_not_self
    if parent_id && parent_id == id
      errors.add(:parent_id, "cannot reference itself")
    end
  end
end
