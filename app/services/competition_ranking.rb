# The standings of a competition, best first, exactly as its page shows them: a competition with children ranks its
# whole subtree by rating (then wins, games, name); one without children ranks its own games by total, then player id.
class CompetitionRanking
  Entry = Data.define(:player_id, :games, :wins, :rating)

  def self.call(competition)
    new(competition).call
  end

  def self.leaf_sort_key(player_id, total)
    [ -total, player_id ]
  end

  def initialize(competition)
    @competition = competition
  end

  def call
    @competition.children.exists? ? subtree_entries : leaf_entries
  end

  private

  def subtree_entries
    Player.with_aggregated_stats.where(games: { competition_id: @competition.subtree_ids }).ranked.map do |player|
      Entry.new(player_id: player.id, games: player.games_count, wins: player.wins_count, rating: player.total_rating)
    end
  end

  def leaf_entries
    GameParticipation.where(game: Game.where(competition: @competition)).group_by(&:player_id)
      .map { |player_id, participations| leaf_entry(player_id, participations) }
      .sort_by { |entry| self.class.leaf_sort_key(entry.player_id, entry.rating) }
  end

  def leaf_entry(player_id, participations)
    Entry.new(player_id: player_id, games: participations.size, wins: participations.count(&:win),
              rating: participations.sum(&:total))
  end
end
