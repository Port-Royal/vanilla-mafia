class CompetitionOverviewService
  Result = Data.define(:parent_view, :games_by_child, :players, :player_count, :games, :participations_by_player, :players_sorted)

  def self.call(competition:)
    new(competition).call
  end

  def initialize(competition)
    @competition = competition
  end

  def call
    if @competition.children.exists?
      parent_result
    else
      leaf_result
    end
  end

  private

  def parent_result
    children = @competition.children.ordered
    games = Game.where(competition_id: children.select(:id)).ordered
    games_by_child = children.index_with { |child| games.select { |g| g.competition_id == child.id } }

    Result.new(
      parent_view: true,
      games_by_child: games_by_child,
      players: Player.with_stats_for_competition(@competition).ranked,
      player_count: Player.joins(game_participations: :game).where(games: { competition_id: @competition.subtree_ids }).distinct.count,
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
      player_count: 0,
      games: games,
      participations_by_player: participations_by_player,
      players_sorted: players_sorted
    )
  end
end
