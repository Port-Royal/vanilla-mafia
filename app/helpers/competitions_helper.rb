module CompetitionsHelper
  def win_percentage(player)
    return 0.0 if player.games_count.zero?

    (player.wins_count.to_f / player.games_count * 100).round(1)
  end

  # A season is split into series; every other parent kind (tournament, …) into stages.
  def children_label(competition, count: nil)
    scope = "competitions.redesign.children.#{competition.season? ? "series" : "stages"}"
    return t("#{scope}.label") if count.nil?

    t("#{scope}.count", count:)
  end

  def competition_dates(competition)
    if competition.ended_on.nil?
      return "" if competition.started_on.nil?

      return t("competitions.redesign.since", date: format_date(competition.started_on))
    end

    [ competition.started_on, competition.ended_on ].compact.map { |date| format_date(date) }.join(" – ")
  end
end
