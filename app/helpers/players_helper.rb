module PlayersHelper
  RESULT_PILLS = { "win" => "vm-pill vm-pill--gold", "lose" => "vm-pill", "draw" => "vm-pill vm-pill--neutral" }.freeze

  # The letter shown in place of a missing photo or award icon.
  def player_initial(name)
    name.lstrip[0].to_s.upcase
  end

  def profile_number_label(key, count)
    t("players.redesign.numbers.#{key}", count:)
  end

  # Nil while the game is in progress. Roles are hidden only then, so the result never gives a hidden role away.
  def profile_result_word(participation)
    result = participation.result
    t("players.redesign.result.#{result}") if result
  end

  def profile_result_pill(participation)
    word = profile_result_word(participation)
    tag.span(word, class: RESULT_PILLS.fetch(participation.result)) if word
  end

  def profile_won?(participation)
    participation.result == "win"
  end

  def profile_game_label(game, root)
    return t("players.redesign.game", number: game.game_number) if game.competition == root

    t("players.redesign.game_in", competition: game.competition.name, number: game.game_number)
  end
end
