module StatsHelper
  RESULT_BAR_CLASSES = { peace_victory: "bg-gold-soft", mafia_victory: "bg-alert-soft", draw: "bg-line" }.freeze

  # Rounded percent; the page shows shares only when some game has finished, so total is positive.
  def stats_share(count, total)
    (count * 100.0 / total).round
  end

  def stats_result_bar_class(result)
    RESULT_BAR_CLASSES.fetch(result)
  end
end
