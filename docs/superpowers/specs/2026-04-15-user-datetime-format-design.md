# User-selectable datetime format (vm-ct5 / GH #791)

## Problem

The app renders datetimes with Rails' English defaults (e.g. `14 Apr 10:30`) because `config/locales/ru.yml` defines only `:full_date` and no `:short`/`:long`/`:default` keys. Russian users perceive this as "US-style" and hard to read. On top of the format issue, `config.time_zone` is unset, so all times are stored and rendered in UTC — a Moscow user seeing `15.04.2026 02:30` for an event that happened at 05:30 MSK will be just as confused as before.

## Goal

Give each user (and anonymous visitors) a preferred datetime format, with a sensible European-24h default, and render every "chrome" datetime in the user's actual time zone, auto-detected from their browser.

## Non-goals

- No full multi-locale i18n overhaul. Only datetime formatting and time zone handling.
- No time-zone override UI. Time zone is always JS-detected. A future issue can add an override if needed.
- No Avo admin customization. Avo screens keep their default datetime rendering; a follow-up issue can address them.
- No styled/custom datetime picker. The admin news form keeps `datetime_local_field` with the browser's native picker.
- Narrative dates (article body "14 апреля 2026") are not user-configurable. They stay on `I18n.l(dt, format: :full_date)`.

## Format presets

Exactly three, stored as a Rails `enum` on `users.datetime_format`:

| Key            | Date         | Datetime                | Example (2026-04-15 15:30) |
|----------------|--------------|-------------------------|----------------------------|
| `european_24h` | `15.04.2026` | `15.04.2026 15:30`      | default                    |
| `iso`          | `2026-04-15` | `2026-04-15 15:30`      |                            |
| `us_12h`       | `04/15/2026` | `04/15/2026 3:30 PM`    |                            |

Boundary cases the formatter must handle:
- `us_12h` noon → `12:00 PM`; midnight → `12:00 AM`.
- Single-digit day/month padded per format (`european_24h` uses `%d.%m.%Y`, `us_12h` uses `%m/%d/%Y`).
- `nil` input → empty string (not exception).

## Data model

One column added to `users`:

```ruby
add_column :users, :datetime_format, :string, default: "european_24h", null: false
```

Enum on `User`:

```ruby
enum :datetime_format, {
  european_24h: "european_24h",
  iso:          "iso",
  us_12h:       "us_12h"
}, default: "european_24h"
```

No `users.time_zone` column. Time zone lives in a cookie only.

No backfill migration needed beyond the column default — existing users get `european_24h` automatically.

## Preference cascade

### datetime_format

1. `current_user.datetime_format` (if signed in)
2. `cookies[:datetime_format]` (anonymous, or signed-in user with no saved pref — but the DB default guarantees they always have one, so this is effectively anonymous-only)
3. `"european_24h"` fallback

### time_zone

1. `cookies[:tz]` — set by JS on first page load
2. `"UTC"` fallback (valid IANA names only; unknown → UTC silently)

Both values are stored on an `ActiveSupport::CurrentAttributes` class for the duration of the request.

## Components

### `app/models/current.rb` (new)

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :datetime_format, :time_zone
end
```

### `app/controllers/concerns/set_preferences.rb` (replaces `set_locale.rb`)

Renames and absorbs `SetLocale`. Runs `before_action :set_preferences` and `around_action :use_time_zone`. Responsibilities:

- Resolve locale (existing logic, unchanged).
- Resolve `datetime_format` via cascade above; assign to `Current.datetime_format`.
- Resolve `time_zone` from `cookies[:tz]`, validate via `ActiveSupport::TimeZone[name]`, fall back to `"UTC"`. Assign to `Current.time_zone`.
- Wrap the request body in `Time.use_zone(Current.time_zone) { yield }`.

Invalid cookie tz values are dropped silently (no flash, no error) to keep the user experience calm. No logging either — cookie tampering is not a security event here, just a display fallback.

### `app/services/datetime_formatter.rb` (new)

Pure service. Input: a `Time`/`Date`/`DateTime`/`ActiveSupport::TimeWithZone`/`nil`, a `style` symbol (`:short` or `:long`), and optionally an explicit format key (defaults to `Current.datetime_format`). Output: formatted `String`.

Format strings live in a single nested constant:

```ruby
FORMATS = {
  european_24h: { short_date: "%d.%m.%Y", short_datetime: "%d.%m.%Y %H:%M", ... },
  iso:          { short_date: "%Y-%m-%d", short_datetime: "%Y-%m-%d %H:%M", ... },
  us_12h:       { short_date: "%m/%d/%Y", short_datetime: "%m/%d/%Y %-I:%M %p", ... }
}.freeze
```

The service does not call `I18n.l`. It converts the input to `Current.time_zone` if it's a `Time`/`DateTime`, then `strftime`s the right format string. `Date` inputs are formatted without zone conversion.

### `app/helpers/datetime_helper.rb` (new)

Two thin wrappers for view code:

```ruby
def format_datetime(value, style: :short)
  DatetimeFormatter.call(value, style: style, type: :datetime)
end

def format_date(value, style: :short)
  DatetimeFormatter.call(value, style: style, type: :date)
end
```

### `app/controllers/datetime_formats_controller.rb` (new)

Mirrors `LocalesController`:

```ruby
class DatetimeFormatsController < ApplicationController
  def update
    fmt = params[:datetime_format]
    return redirect_back(fallback_location: root_path) unless valid_format?(fmt)

    cookies[:datetime_format] = { value: fmt, expires: 1.year.from_now }
    current_user.update!(datetime_format: fmt) if user_signed_in?

    redirect_back(fallback_location: root_path)
  end

  private

  def valid_format?(fmt)
    User.datetime_formats.key?(fmt.to_s)
  end
end
```

Route: `resource :datetime_format, only: [:update]` next to the existing `resource :locale, only: [:update]`.

### Stimulus controller `app/javascript/controllers/time_zone_controller.js` (new)

~15 lines. Attaches to `<body data-controller="time-zone">`. On `connect()`:

```js
if (document.cookie.split('; ').some((c) => c.startsWith('tz='))) return;
const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
if (!zone) return;
const expires = new Date(Date.now() + 365 * 86400 * 1000).toUTCString();
document.cookie = `tz=${encodeURIComponent(zone)}; expires=${expires}; path=/; SameSite=Lax`;
window.location.reload();
```

The reload happens once per browser lifetime (cookie has 1-year expiry). Subsequent loads are a no-op because the cookie exists. `tz` is never modified server-side except through this flow.

### Footer switcher `app/views/layouts/_datetime_format_switcher.html.erb` (new)

Sibling of `_locale_switcher.html.erb`, same visual style (inline `button_to`s for each of the three formats, current one bolded white). Rendered next to the locale switcher in the layout.

## Call-site migration

### Chrome dates → `format_datetime` / `format_date`

| File | Line | Before | After |
|------|------|--------|-------|
| `app/views/players/show.html.erb` | 26 | `l(@stats.first_game_date, format: :short)` | `format_date(@stats.first_game_date)` |
| `app/views/podcast/episodes/index.html.erb` | — | `l(episode.published_at, format: :short)` | `format_datetime(episode.published_at)` |
| `app/views/podcast/episodes/show.html.erb` | — | same | same |
| `app/views/podcast/playlists/show.html.erb` | — | same | same |
| `app/views/home/_recently_finished.html.erb` | 13 | `l(..., format: :short)` | `format_datetime(...)` |
| `app/views/home/_recent_games.html.erb` | 13 | same | same |
| `app/views/home/_latest_news.html.erb` | 12 | same | same |
| `app/views/competitions/show.html.erb` | 100 | `l(article.published_at, format: :short)` | `format_datetime(article.published_at)` |
| `app/views/admin/news/index.html.erb` | 48 | `l(article.created_at.to_date)` | `format_date(article.created_at)` |
| `app/views/admin/news/index.html.erb` | 49 | `l(article.published_at, format: :short)` | `format_datetime(article.published_at)` |
| `app/views/admin/news/edit.html.erb` | — | `l(@news.created_at.to_date)` | `format_date(@news.created_at)` |
| `app/views/admin/news/show.html.erb` | — | same | same |

### Narrative dates → leave alone

- `app/views/news/_preview_list.html.erb:9` — `l(article.published_at, format: :full_date)`
- `app/views/news/_article.html.erb:9` — same
- `app/views/news/show.html.erb:10` — same

### Non-display → leave alone

- `app/models/news.rb:74` — `slug_date.strftime('%Y-%m-%d')` is slug generation, not display.

### Form input → leave alone

- `app/views/admin/news/_form.html.erb:45` — `f.datetime_local_field :published_at` stays as native browser picker. The pre-filled value will now reflect the user's time zone correctly thanks to `Time.use_zone`, which is a silent correctness improvement.

## Precedence & auth transitions

- Anonymous with no cookies → `european_24h` + UTC. JS fires on first load, sets `tz` cookie, reloads, now gets UTC → MSK (or whatever).
- Anonymous with format cookie → cookie wins.
- Anonymous → signs in: `current_user.datetime_format` (DB default `european_24h`) takes precedence over any format cookie. If the user had clicked a non-default format while anonymous, that preference is lost on sign-in. This is acceptable for MVP; copying the cookie into the user record on sign-in is explicitly out of scope.
- Signed-in user changes format: controller writes both DB and cookie, cookie won't matter on next request but keeps both aligned.
- Cookie tz is tampered with a bogus value → silent UTC fallback.

## Testing

### Unit

- `spec/services/datetime_formatter_spec.rb` — 3 formats × 2 styles × 2 types × edge cases (nil, noon/midnight for 12h, single-digit day/month padding, DST boundary via explicit Europe/Moscow winter→summer if relevant). Assert exact output strings.
- `spec/models/user_spec.rb` — enum values, default, invalid value raises `ArgumentError`.
- `spec/models/current_spec.rb` — `Current.datetime_format` and `Current.time_zone` isolated per request (use `Current.reset` between examples).
- `spec/helpers/datetime_helper_spec.rb` — delegation correctness.

### Request / integration

- `spec/requests/datetime_formats_spec.rb` — `PATCH /datetime_format`: valid value with signed-in user writes DB + cookie; valid value anonymous writes cookie only; invalid value redirects back with no writes; missing param redirects back.
- `spec/controllers/concerns/set_preferences_spec.rb` (or equivalent request spec against a canary action) — cascade precedence, invalid cookie tz falls back to UTC, `Time.use_zone` is active during the action body.
- `spec/requests/admin/news_spec.rb` — add one test: signed-in admin with `datetime_format: :iso` and `tz: "Europe/Moscow"` cookie sees the index page rendering `published_at` in ISO + Moscow time.

### System / feature

Skipped. Acceptance tests are excluded from CI (vm-ct5 is not a gate on vm-38). JS cookie detection is covered at unit level by stubbing `Intl.DateTimeFormat`.

### Mutation testing

Run both `evilution` and `mutant` against:

- `DatetimeFormatter`
- `Current`
- `SetPreferences` (concern) and `DatetimeFormatsController`
- `User` (enum branch)

Format strftime strings and cascade branches are mutation-rich. Boundary tests on 12h/24h, single-digit padding, and UTC fallback are the ones that kill otherwise-surviving mutants.

### Deterministic time

All specs asserting formatted output use `travel_to(Time.zone.local(2026, 4, 15, 15, 30))` in `Europe/Moscow` to keep output stable regardless of CI wall-clock or server timezone.

## Files touched

**New:**
- `app/models/current.rb`
- `app/services/datetime_formatter.rb`
- `app/helpers/datetime_helper.rb`
- `app/controllers/datetime_formats_controller.rb`
- `app/controllers/concerns/set_preferences.rb` (replaces `set_locale.rb`)
- `app/javascript/controllers/time_zone_controller.js`
- `app/views/layouts/_datetime_format_switcher.html.erb`
- `db/migrate/YYYYMMDDHHMMSS_add_datetime_format_to_users.rb`
- Specs listed above.

**Modified:**
- `app/models/user.rb` — add `enum :datetime_format`
- `app/controllers/application_controller.rb` — swap `include SetLocale` for `include SetPreferences`
- `config/routes.rb` — add `resource :datetime_format, only: [:update]`
- `app/views/layouts/application.html.erb` (or the actual layout) — add `data-controller="time-zone"` to `<body>` and render the new switcher
- All chrome-date view files listed in the call-site migration table.

**Deleted:**
- `app/controllers/concerns/set_locale.rb` (folded into `set_preferences.rb`)

## Rollout

Single PR. Migration is additive with a default, so it's zero-downtime. No feature flag — the change is visible immediately once merged.

## Mutation / quality gates (per CLAUDE.md)

- Rubocop clean on all changed files.
- RSpec green.
- Evilution + Mutant clean on `DatetimeFormatter`, `Current`, `SetPreferences`, `DatetimeFormatsController`.
- PR description lists both mutation scores.
- Both beads `vm-ct5` and GH #791 closed on merge.
