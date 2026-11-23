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

  # A competition's name, then its ancestors' names up to the root: series names repeat across seasons.
  def competition_title_parts(competition)
    [ competition, *competition.ancestors.reverse ].map(&:name)
  end
end
