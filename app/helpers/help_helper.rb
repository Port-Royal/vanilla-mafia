module HelpHelper
  Section = Data.define(:anchor, :title)

  # A help page writes its section headings through this, so the contents list is built from the headings themselves.
  def help_heading(anchor, title)
    help_sections << Section.new(anchor, title)
    tag.h2(title, id: anchor)
  end

  def help_sections
    @help_sections ||= []
  end
end
