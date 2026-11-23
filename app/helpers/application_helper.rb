module ApplicationHelper
  SITE_NAME = "Vanilla Mafia"
  TITLE_SEPARATOR = " — "

  def featured_competitions
    @featured_competitions ||= Competition.featured.ordered
  end

  # The browser tab title: the page's own parts, most specific first, then the site name.
  def page_title(*parts)
    safe_join(parts + [ SITE_NAME ], TITLE_SEPARATOR)
  end
end
