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
  validate :parent_does_not_loop_back

  scope :featured, -> { where(featured: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :roots, -> { where(parent_id: nil) }
  scope :running, -> { where(ended_on: nil) }
  scope :finished, -> { where.not(ended_on: nil) }
  scope :recently_finished, -> { finished.order(ended_on: :desc, id: :desc) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def to_param
    slug
  end

  # In rows saved with parents in a loop, the loop's member created first stands in as the root, so every competition
  # of that tree gets the same one wherever the walk starts.
  def root
    path = [ self, *parent_chain ]
    repeated = path.last.parent
    return path.last if repeated.nil?

    path.drop_while { |node| node.id != repeated.id }.min_by(&:id)
  end

  def ancestors
    parent_chain.reverse
  end

  def subtree_ids
    self.class.connection.select_values(subtree_ids_sql)
  end

  private

  # Parents from the nearest up. The walk stops at a competition it has already passed, so rows saved in a loop
  # before the loop check existed can't hang a page.
  def parent_chain
    chain = []
    seen = Set[id]
    node = parent
    while node && seen.add?(node.id)
      chain << node
      node = node.parent
    end
    chain
  end

  # UNION (not UNION ALL) drops rows already found, so a loop in saved rows ends the recursion.
  def subtree_ids_sql
    sanitized_id = self.class.connection.quote(id)
    <<~SQL
      WITH RECURSIVE subtree AS (
        SELECT id FROM competitions WHERE id = #{sanitized_id}
        UNION
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

  # A parent whose own parents lead back here would make the tree a loop. Self-parenting is reported above.
  def parent_does_not_loop_back
    return if parent_id == id

    errors.add(:parent_id, :parent_loop) if parent_leads_back?
  end

  def parent_leads_back?
    seen = Set.new
    node = parent
    while node && seen.add?(node.id)
      return true if node.id == id

      node = node.parent
    end
    false
  end
end
