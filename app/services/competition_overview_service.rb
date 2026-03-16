class CompetitionOverviewService
  Result = Data.define(:parent_view, :games_by_child, :players, :player_count, :games, :participations_by_player, :players_sorted)

  def self.call(competition:)
    new(competition).call
  end

  def initialize(competition)
    @competition = competition
  end

  def call
    children = @competition.children.ordered
    if children.any?
      parent_result(children)
    else
      leaf_result
    end
  end

  private

  def parent_result(children)
    subtree_ids = @competition.subtree_ids
    games_by_competition_id = Game.where(competition_id: children.select(:id)).ordered.to_a.group_by(&:competition_id)
    games_by_child = children.index_with { |child| games_by_competition_id.fetch(child.id, []) }

    Result.new(
      parent_view: true,
      games_by_child: games_by_child,
      players: Player.with_stats_for_competition(@competition).ranked,
      player_count: Player.joins(game_participations: :game).where(games: { competition_id: subtree_ids }).distinct.count,
      games: [],
      participations_by_player: {},
      players_sorted: []
    )
  end

  def leaf_result
    games = Game.where(competition: @competition).ordered
    participations_by_player = GameParticipation.where(game: games).includes(:player).group_by(&:player)
    players_sorted = participations_by_player.keys.sort_by { |p| [ -participations_by_player[p].sum(&:total), p.id ] }

    Result.new(
      parent_view: false,
      games_by_child: {},
      players: [],
      player_count: participations_by_player.size,
      games: games,
      participations_by_player: participations_by_player,
      players_sorted: players_sorted
    )
  end
end
