class CompetitionOverviewService
  Result = Data.define(:parent_view, :games_by_child, :players, :games, :participations_by_player,
                       :players_sorted, :news)

  def self.call(competition:)
    new(competition).call
  end

  def initialize(competition)
    @competition = competition
  end

  def call
    if children.any?
      parent_result
    else
      leaf_result
    end
  end

  # The top of each finished child's standings, as on the home page; a running child has no winner yet. Only the
  # redesigned page shows them, so they are computed on demand: one query per finished child, plus one for the
  # subtree's links when any child has finished.
  def child_winners
    children.index_with { |child| winner_of(child) unless child.ended_on.nil? }
  end

  private

  def children
    @children ||= @competition.children.ordered.to_a
  end

  def subtree_ids
    @subtree_ids ||= @competition.subtree_ids
  end

  def parent_result
    games_by_competition_id = Game.where(competition_id: subtree_ids).ordered.to_a.group_by(&:competition_id)
    games_by_child = children.index_with { |child| games_by_competition_id.fetch(child.id, []) }

    Result.new(
      parent_view: true,
      games_by_child: games_by_child,
      players: Player.with_aggregated_stats.where(games: { competition_id: subtree_ids }).ranked,
      games: Game.none,
      participations_by_player: {},
      players_sorted: [],
      news: news_for_competition
    )
  end

  def leaf_result
    games = Game.where(competition: @competition).ordered
    participations_by_player = GameParticipation.where(game: games).includes(:player).group_by(&:player)
    players_sorted = participations_by_player.keys.sort_by { |p| [ -participations_by_player[p].sum(&:total), p.id ] }

    Result.new(
      parent_view: false,
      games_by_child: {},
      games: games,
      players: [],
      participations_by_player: participations_by_player,
      players_sorted: players_sorted,
      news: news_for_competition
    )
  end

  def winner_of(child)
    Player.with_aggregated_stats.where(games: { competition_id: subtree_of(child.id) }).ranked.first
  end

  def subtree_of(id)
    [ id, *child_ids_by_parent_id.fetch(id, []).flat_map { |child_id| subtree_of(child_id) } ]
  end

  # The links inside the already known subtree, so a child's own subtree needs no recursive query of its own.
  def child_ids_by_parent_id
    @child_ids_by_parent_id ||= Competition.where(id: subtree_ids).pluck(:parent_id, :id)
                                           .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  def news_for_competition
    News.visible.for_competition(@competition).includes({ author: :player }, :tags, :rich_text_content, photos_attachments: :blob).recent
  end
end
