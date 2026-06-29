# frozen_string_literal: true

# Default items per page (pagy 43 reads global defaults from Pagy::OPTIONS;
# the old Pagy::DEFAULT constant is now frozen and must not be mutated).
Pagy::OPTIONS[:limit] = 25

# Out-of-range pages are handled gracefully by default in pagy 43 (an empty
# page is returned instead of raising), so the former `pagy/extras/overflow`
# require and `:overflow => :last_page` option are no longer needed.
#
# Pagination labels and aria-labels are rendered through the standard Rails
# I18n gem in app/views/shared/_pagy_nav.html.erb (see the `pagy:` keys in
# config/locales/*.yml), so the former `pagy/extras/i18n` require is gone too.

# Pagy 43 made Pagy#series protected (it is meant to be consumed by the built-in
# `*_series_nav` helpers). Our custom Tailwind nav partial builds its own markup
# from the series array, so re-expose #series as a public reader.
module PagyPublicSeries
  def series(...) = super
end
Pagy.prepend(PagyPublicSeries)
