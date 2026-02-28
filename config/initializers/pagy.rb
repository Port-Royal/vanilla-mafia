# frozen_string_literal: true

# Pagy initializer (9.4.0)

# Items per page
Pagy::DEFAULT[:limit] = 25

# Use the overflow extra to handle out-of-range pages gracefully
require "pagy/extras/overflow"
Pagy::DEFAULT[:overflow] = :last_page

# Use the standard I18n gem so pagy respects the app locale (ru / en)
require "pagy/extras/i18n"

Pagy::DEFAULT.freeze
