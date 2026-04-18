module GamesHelper
  OVERLAY_STATUS_CLASSES = {
    alive: "bg-green-700/70 text-green-100",
    killed_by_mafia: "bg-red-700/70 text-red-100",
    voted_out: "bg-orange-700/70 text-orange-100",
    banned: "bg-gray-700/70 text-gray-100"
  }.freeze

  def overlay_custom_style(config)
    parts = []
    parts << "font-size: #{config[:font_size]}px" if config[:font_size]
    parts << "color: ##{config[:color]}" if config[:color]
    parts.join("; ")
  end

  def overlay_player_status(participation)
    return nil unless participation

    participation.status.to_sym
  end

  def overlay_status_class(status)
    OVERLAY_STATUS_CLASSES.fetch(status, "")
  end
end
