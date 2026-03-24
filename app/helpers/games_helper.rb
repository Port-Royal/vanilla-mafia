module GamesHelper
  def overlay_custom_style(config)
    parts = []
    parts << "font-size: #{config[:font_size]}px" if config[:font_size]
    parts << "color: ##{config[:color]}" if config[:color]
    parts.join("; ")
  end
end
