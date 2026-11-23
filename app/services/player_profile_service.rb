class PlayerProfileService
  Result = Data.define(:player, :competitions_with_games, :player_awards, :news_articles, :stats,
                       :competition_summaries, :award_badges)
  Stats = Data.define(:total_games, :total_wins, :win_rate, :first_game_date, :role_stats)
  RoleStat = Data.define(:role_code, :role_name, :games, :wins, :win_rate)
  CompetitionGames = Data.define(:competition, :games)
  CompetitionSummary = Data.define(:competition, :participations, :place, :ranked_count, :games_count, :wins_count, :rating,
                                   :running)

  def self.call(player_slug:)
    new(player_slug).call
  end

  def initialize(player_slug)
    @player_slug = player_slug
  end

  def call
    player = Player.find_by!(slug: @player_slug)
    participations = player.game_participations.includes(:role, :game)
    player_awards = player.player_awards.ordered.includes(:competition, award: { icon_attachment: :blob }).load

    Result.new(
      player: player,
      competitions_with_games: build_competitions_with_games(player),
      player_awards: player_awards,
      news_articles: News.mentioning_player(player)
        .includes({ author: :player }, :tags, :rich_text_content, photos_attachments: :blob),
      stats: build_stats(participations),
      competition_summaries: build_competition_summaries(player),
      award_badges: build_award_badges(player_awards)
    )
  end

  private

  # One row per root competition, running (or undated) ones first, then the newest finished. Place and counts come
  # from the same ranking the competition's own page shows.
  def build_competition_summaries(player)
    participations = player.game_participations.joins(:game).includes(:role, game: { competition: :parent })
      .order("games.played_on DESC, games.game_number DESC, games.id DESC")
    participations.group_by { |participation| participation.game.competition.root }
      .map { |root, root_participations| competition_summary(player, root, root_participations) }
      .sort_by { |summary| summary_sort_key(summary.competition) }
  end

  def competition_summary(player, root, participations)
    ranking = CompetitionRanking.call(root)
    index = ranking.index { |entry| entry.player_id == player.id }
    entry = ranking.fetch(index)

    CompetitionSummary.new(
      competition: root, participations: participations, place: index + 1, ranked_count: ranking.size,
      games_count: entry.games, wins_count: entry.wins, rating: entry.rating, running: root.ended_on.nil?
    )
  end

  def summary_sort_key(competition)
    running = competition.ended_on.nil? || competition.started_on.nil?
    started = competition.started_on ? -competition.started_on.jd : -Float::INFINITY
    [ running ? 0 : 1, started, -competition.id ]
  end

  def build_award_badges(player_awards)
    player_awards.group_by(&:award)
      .sort_by.with_index { |(award, _), index| [ award.staff? ? 0 : 1, index ] }
      .map { |award, wins| AwardBadge.new(award: award, competitions: wins.filter_map(&:competition)) }
  end

  def build_competitions_with_games(player)
    games = player.games.includes(:game_participations, competition: :parent).ordered
    games.group_by { |g| g.competition.root }
      .map { |root, root_games| CompetitionGames.new(competition: root, games: root_games) }
      .sort_by { |cg| cg.competition.started_on || Date.new(0) }
      .reverse
  end

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
      .select { |p| p.role_code.present? && p.game.roles_public? }
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
