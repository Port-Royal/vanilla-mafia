module ResultsHelper
  RESULT_PILL_MODIFIERS = {
    "peace_victory" => "vm-pill--gold",
    "mafia_victory" => "vm-pill--alert",
    "draw" => "vm-pill--neutral",
    "in_progress" => "vm-pill--neutral"
  }.freeze

  def game_result_pill(game)
    tag.span(t("activerecord.attributes.game.results.#{game.result}"),
             class: [ "vm-pill", RESULT_PILL_MODIFIERS.fetch(game.result) ])
  end
end
