# The club's numbers for the stats page: the totals the old home page showed, finished games by result and a row per
# root competition. A fixed number of queries whatever the data size.
class ClubStatsService
  Result = Data.define(:totals, :first_game_on, :results, :competitions)
  CompetitionRow = Data.define(:competition, :games_count, :players_count, :peace_wins, :mafia_wins)

  RESULTS = Game::RESULTS.except(:in_progress).freeze

  def self.totals
    {
      players: Player.count,
      games: Game.finished.count,
      competitions: Competition.roots.finished.count
    }
  end

  def self.call
    new.call
  end

  def call
    Result.new(
      totals: self.class.totals,
      first_game_on: Game.finished.minimum(:played_on),
      results: RESULTS.transform_values { |result| results_by_root.values.sum { |counts| counts[result] } },
      competitions: competition_rows
    )
  end

  private

  # Roots without a finished game are left out; newest first, keeping the admin's order.
  def competition_rows
    Competition.roots.ordered.reverse_order.filter_map do |root|
      counts = results_by_root[root.id]
      next unless counts

      CompetitionRow.new(
        competition: root,
        games_count: counts.values.sum,
        players_count: players_count_by_root.fetch(root.id, 0),
        peace_wins: counts[RESULTS[:peace_victory]],
        mafia_wins: counts[RESULTS[:mafia_victory]]
      )
    end
  end

  # { root id => { result => finished games } }, a subtree's games counted for its root.
  def results_by_root
    @results_by_root ||= Game.finished.group(:competition_id, :result).count
                             .each_with_object({}) do |((competition_id, result), count), by_root|
      counts = by_root[root_ids.fetch(competition_id)] ||= Hash.new(0)
      counts[result] += count
    end
  end

  def players_count_by_root
    @players_count_by_root ||=
      GameParticipation.joins(:game).merge(Game.finished).distinct.pluck("games.competition_id", :player_id)
                       .group_by { |competition_id, _| root_ids.fetch(competition_id) }
                       .transform_values { |pairs| pairs.map(&:last).uniq.size }
  end

  # { competition id => its root's id }, from one query over the whole competitions table. The walk stops at a
  # competition it has already seen, so parents saved in a loop can't hang the page; such a loop has no root and is
  # left out of the table.
  def root_ids
    @root_ids ||= begin
      parents = Competition.pluck(:id, :parent_id).to_h
      parents.keys.index_with do |id|
        seen = Set[id]
        id = parents.fetch(id) while parents.fetch(id) && seen.add?(parents.fetch(id))
        id
      end
    end
  end
end
