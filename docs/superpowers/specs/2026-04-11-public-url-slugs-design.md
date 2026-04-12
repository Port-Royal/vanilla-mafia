# Public URL Slugs — Design Spec

**Epic:** vm-49 (gh-703) — Replace numeric IDs with slugs in public URLs
**Date:** 2026-04-11
**Status:** Approved

## Goal

Replace database record IDs with human-readable slugs in all public-facing URLs for players, games, news, podcast episodes, and podcast playlists. Competitions and help pages already use slugs. Admin routes are out of scope and keep numeric IDs.

Hard cutover: no redirects from legacy numeric URLs. Old links will 404 after the rollout.

## Architecture

Two shared pieces of infrastructure built once, then each of the five affected entities applies them via a thin per-model task.

### Shared infrastructure (vm-t11)

**`CyrillicTransliterator`** — PORO in `app/services/cyrillic_transliterator.rb`. Single class method `.call(string)` returning an ASCII string via a lookup table covering all Russian letters (upper and lower case). Non-Cyrillic characters (including case and whitespace) pass through unchanged. Nil is treated as empty string.

```ruby
class CyrillicTransliterator
  TABLE = {
    "а"=>"a","б"=>"b","в"=>"v","г"=>"g","д"=>"d","е"=>"e","ё"=>"yo",
    "ж"=>"zh","з"=>"z","и"=>"i","й"=>"y","к"=>"k","л"=>"l","м"=>"m",
    "н"=>"n","о"=>"o","п"=>"p","р"=>"r","с"=>"s","т"=>"t","у"=>"u",
    "ф"=>"f","х"=>"kh","ц"=>"ts","ч"=>"ch","ш"=>"sh","щ"=>"shch",
    "ъ"=>"","ы"=>"y","ь"=>"","э"=>"e","ю"=>"yu","я"=>"ya"
  }.freeze

  def self.call(string)
    string.to_s.each_char.map { |c| TABLE[c.downcase] || c }.join
  end
end
```

**`Sluggable` concern** — in `app/models/concerns/sluggable.rb`. Models include it and declare the source attribute. Provides slug generation, `to_param` override, and validation.

```ruby
module Sluggable
  extend ActiveSupport::Concern

  TAIL_BYTES = 2  # -> 4 hex characters

  class_methods do
    attr_reader :slug_source_attribute, :slug_source_condition

    def slug_source(attribute, if: nil)
      @slug_source_attribute = attribute
      @slug_source_condition = binding.local_variable_get(:if)
    end
  end

  included do
    validates :slug, presence: true, uniqueness: true
    before_validation :generate_slug, if: :should_generate_slug?
  end

  def to_param
    slug
  end

  private

  def should_generate_slug?
    return false if slug.present?

    condition = self.class.slug_source_condition
    condition.nil? || instance_exec(&condition)
  end

  def generate_slug
    base = slug_base
    candidate = base
    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{SecureRandom.hex(Sluggable::TAIL_BYTES)}"
    end
    self.slug = candidate
  end

  def slug_base
    raw = public_send(self.class.slug_source_attribute).to_s
    CyrillicTransliterator.call(raw).parameterize.presence ||
      SecureRandom.hex(Sluggable::TAIL_BYTES)
  end
end
```

Design notes:
- **Freeze after create:** `should_generate_slug?` returns false once a slug exists, so editing the source attribute later does not change the URL.
- **Pre-save uniqueness:** the `exists?` loop guarantees a free slug before validation. The `validates :slug, uniqueness: true` call is a belt-and-suspenders check. The unique database index is the final backstop for true races.
- **No Rails internals overridden:** no monkey-patch of `save`/`create_or_update`. True concurrent races (vanishingly rare here — creation is single-threaded via importer or admin forms) raise `ActiveRecord::RecordNotUnique` from the index, which callers handle as a normal error.
- **Extensible via override:** subclasses can override the private `slug_base` method to customise the generation logic (News uses this for the date prefix).
- **Defensive fallback:** if transliteration yields an empty string (e.g., blank title), slug falls back to a random hex tail so the record is still valid.

### Per-entity implementation (vm-50 .. vm-54)

Each per-entity task follows the same six-step recipe:

1. **Migration A** — add `slug:string` column (nullable), add unique index on `slug`
2. **Data migration** — backfill slugs for existing records using the Sluggable machinery (`find_each` + `save!`)
3. **Migration B** — flip `slug` to `NOT NULL` (News is the exception: stays nullable)
4. **Model change** — `include Sluggable` + `slug_source :attr` declaration
5. **Route change** — add `param: :slug` to the resource
6. **Controller change** — look up by `find_by!(slug:)` instead of `find`
7. **Call-site audit** — grep for hardcoded `/<entity>/#{id}` URLs and update (notably the autolink service for players)

## Per-entity specifics

### Players (vm-50)

- `slug_source :nickname`
- Cyrillic nicknames are transliterated. Collisions between players with the same transliterated nickname get a 4-hex-character tail (e.g., `ivan-petrov-a3f2`).
- Public routes: `resources :players, only: [:show], param: :slug` and nested `resource :claim` / `resource :dispute`.
- Controllers to update: `PlayersController#show`, `PlayerClaimsController#create`, `PlayerDisputesController#new`, `PlayerDisputesController#create`.
- **Known call site:** `AutolinkPlayersInNewsService` builds anchors with `href="/players/#{id}"` and must be updated to use the slug.
- **Importer:** phase 2 of `rake import:scrape` creates players via `Player.find_or_initialize_by(id:)` inside a wrapping transaction. Sluggable's auto-generation covers this on first run; re-runs are idempotent because generation is gated on `slug.blank?`. Acceptance criterion: re-running `rake import:scrape` against a seeded DB must succeed without errors.

### Games (vm-51)

- Slug is purely numeric: `season-<season>-game-<game_number>`. No transliteration needed, but the model still uses Sluggable for uniformity.
- Because Game doesn't have a single source attribute that yields the desired format, the model either overrides `slug_base` or defines a `slug_source_text` method and declares `slug_source :slug_source_text`. The spec prefers the latter — less machinery, easier to test.
- Public routes: `resources :games, only: [:show], param: :slug` including the `:overlay` member route.
- Controllers: `GamesController#show`, `GamesController#overlay`.
- **Importer:** same idempotency requirement as Players.

### News (vm-52)

Most complex of the five. News has draft and published states (`status` enum with `published_at` timestamp).

- **Date-prefixed slug:** `YYYY-MM-DD-<transliterated title>`, e.g., `2026-04-11-alex-scored-hat-trick`.
- **Generation gated on publish:** drafts have no slug. Slug is generated at the moment `published_at` becomes present (typically on first publish).
- **Frozen after generation:** editing the title of a published article does not change the URL.
- **Nullable slug column:** News does NOT add a NOT NULL constraint, because drafts legitimately have no slug. Public `NewsController#show` already filters to visible (published) news, so `News.visible.find_by!(slug: params[:slug])` is naturally safe.
- **Backfill:** data migration backfills published articles only. Drafts keep `slug = NULL`.

Model code:

```ruby
class News < ApplicationRecord
  include Sluggable
  slug_source :title, if: -> { published_at.present? }

  # ...

  private

  def slug_base
    date_prefix = published_at.to_date.iso8601
    raw_title = CyrillicTransliterator.call(title.to_s).parameterize.presence || "news"
    "#{date_prefix}-#{raw_title}"
  end
end
```

- Public route: `resources :news, only: [:index, :show], param: :slug`.
- Admin routes (`/admin/news/:id`) keep numeric IDs — out of scope.

### Podcast::Episode (vm-53)

- `slug_source :title`, plain transliterated title, frozen on create.
- Public routes under `namespace :podcast`: `resources :episodes, param: :slug` including nested `resource :position` and `resource :audio`.
- Controllers: `Podcast::EpisodesController#show`, `Podcast::PlaybackPositionsController`, `Podcast::AudioController`.
- **RSS feed investigation:** `Podcast::FeedController` generates the podcast XML feed. Before rolling out, check whether episode GUIDs in the feed are derived from URLs. If they are, switching episode URLs will appear as new episodes to existing podcast subscribers, breaking their playback history. If GUIDs are DB-ID-based (stable), it's a non-issue. This investigation happens as part of vm-53 and its finding is documented in the PR description. If breakage is expected, it must be coordinated with listeners before rollout.

### Podcast::Playlist (vm-54)

- `slug_source :title`, plain transliterated title, frozen on create.
- Public route: `resources :playlists, param: :slug` under `namespace :podcast`.
- Controller: `Podcast::PlaylistsController#show`.

## Testing

### vm-t11 (shared infrastructure)

**`CyrillicTransliterator`:**
- All 33 Russian letters (upper and lower case)
- Mixed Cyrillic/Latin input
- Non-Cyrillic passthrough (Latin, digits, punctuation, whitespace)
- Empty string
- Multi-character mappings (ё, ж, х, ц, ч, ш, щ, ю, я)
- Soft/hard sign (ъ, ь) erasure

**`Sluggable` concern:** tested via an anonymous test model created in the spec with `ActiveRecord::Base.connection.create_table`. Test cases:
- Sets slug from source attribute on create
- Transliterates Cyrillic source via `CyrillicTransliterator`
- Overrides `to_param` to return slug
- Appends hex tail on collision (seed an existing record with the same base slug)
- Freezes slug once set (re-save with a modified source attribute does not regenerate)
- Validation fails when slug ends up blank
- Respects `if:` condition on `slug_source` — skips generation when condition returns false
- Fallback to random hex tail when source yields empty after transliteration

### Per-entity tests (vm-50 .. vm-54)

Each entity:
- Model spec: slug generation, freezing on create, correct source attribute
- Request spec: hitting `/<entity>/:slug` renders the page, unknown slug returns 404
- Link-helper spec: `entity_path(record)` returns slug-based path
- Mutation testing on all new files (evilution + mutant per project convention)

Entity-specific:
- **Player (vm-50):** integration test that `AutolinkPlayersInNewsService` emits slug-based anchor tags, not `/players/#{id}`. Importer re-run test.
- **Game (vm-51):** slug format matches `season-N-game-M`. Importer re-run test.
- **News (vm-52):** draft has no slug; publishing a draft generates the slug with date prefix; editing title after publish does not change slug; direct creation of a published article generates slug immediately.
- **Podcast::Episode (vm-53):** RSS feed continues to serve episodes with stable GUIDs (after the investigation confirms the behaviour).
- **Podcast::Playlist (vm-54):** no extra edge cases.

## Rollout order

```
vm-t11 (shared infra)  ──┬──► vm-50 (Players)
                         ├──► vm-51 (Games)
                         ├──► vm-52 (News)
                         ├──► vm-53 (Podcast Episodes)
                         └──► vm-54 (Podcast Playlists)
```

vm-t11 ships first and can merge to master standalone — no routes change, no user-visible effect. After that, vm-50 through vm-54 are independent and can be implemented in any order.

Recommended order by risk/value:

1. **vm-50 (Players)** — highest visibility, validates the end-to-end pipeline including the `AutolinkPlayersInNewsService` call site shipped in vm-80/81
2. **vm-51 (Games)** — simplest (numeric slug, no transliteration)
3. **vm-52 (News)** — most complex (date prefix, publish-time generation)
4. **vm-53 (Podcast Episodes)** — includes RSS feed investigation
5. **vm-54 (Podcast Playlists)** — simplest content entity

## Out of scope

- Redirects from legacy numeric URLs (hard cutover decided)
- Admin routes (continue to use numeric IDs)
- Competitions and help pages (already on slugs)
- Automatic slug regeneration on source attribute change (frozen by design)
- Changing the public URL shape (still `/<entity>/:slug`, no nested routes like `/news/:year/:month/:slug`)
