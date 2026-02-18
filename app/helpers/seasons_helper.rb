module SeasonsHelper
  def win_percentage(player)
    return 0 if player.games_count.zero?

    (player.wins_count.to_f / player.games_count * 100).round(1)
  end
end
