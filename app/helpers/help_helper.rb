module HelpHelper
  Section = Data.define(:anchor, :title)

  # One key, optionally with modifiers: "F", "1", "Enter", "Shift+F", "Ctrl+Z".
  KEY = /\A(?:(?:Shift|Ctrl|Alt)\+)?(?:[A-Z0-9]|Enter|Space|Esc|Tab)\z/
  KEY_SEPARATOR = ", "

  # A help page writes its section headings through this, so the contents list is built from the headings themselves.
  def help_heading(anchor, title)
    help_sections << Section.new(anchor, title)
    tag.h2(title, id: anchor)
  end

  def help_sections
    @help_sections ||= []
  end

  # A key table cell lists keys ("F, G, X") or describes an action in words ("номер или Enter").
  # Each key of a list gets its own cap; a cell in words stays one cap, since splitting it would misread it.
  def help_key_caps(cell)
    keys = cell.split(KEY_SEPARATOR)
    return tag.kbd(cell) unless keys.all?(KEY)

    safe_join(keys.map { |key| tag.kbd(key) }, KEY_SEPARATOR)
  end
end
