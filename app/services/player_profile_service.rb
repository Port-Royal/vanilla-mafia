class PlayerProfileService
  Result = Data.define(:player, :games, :player_awards, :news_articles, :stats)
  Stats = Data.define(:total_games, :total_wins, :win_rate, :first_game_date, :role_stats)
  RoleStat = Data.define(:role_code, :role_name, :games, :wins, :win_rate)

  def self.call(player_id:)
    new(player_id).call
  end

  def initialize(player_id)
    @player_id = player_id
  end

  def call
    player = Player.find(@player_id)
    participations = player.game_participations.includes(:role, :game)

    Result.new(
      player: player,
      games: player.games.includes(competition: :parent).ordered,
      player_awards: player.player_awards.ordered.includes(:award).load,
      news_articles: News.mentioning_player(player).includes({ author: :player }, :tags, :rich_text_content),
      stats: build_stats(participations)
    )
  end

  private

  def build_stats(participations)
    loaded = participations.to_a
    total_games = loaded.size
    total_wins = loaded.count(&:win)

    Stats.new(
      total_games: total_games,
      total_wins: total_wins,
      win_rate: total_games.zero? ? 0.0 : (total_wins * 100.0 / total_games).round(1),
      first_game_date: loaded.filter_map { |p| p.game.played_on }.min,
      role_stats: build_role_stats(loaded)
    )
  end

  def build_role_stats(participations)
    participations
      .select { |p| p.role_code.present? }
      .group_by(&:role_code)
      .map do |role_code, role_participations|
        games = role_participations.size
        wins = role_participations.count(&:win)
        RoleStat.new(
          role_code: role_code,
          role_name: role_participations.first.role.name,
          games: games,
          wins: wins,
          win_rate: (wins * 100.0 / games).round(1)
        )
      end
      .sort_by { |rs| [ -rs.games, rs.role_code ] }
  end
end
