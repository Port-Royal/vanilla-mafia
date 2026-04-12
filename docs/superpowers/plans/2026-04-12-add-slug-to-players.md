# Add Slug to Players — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace numeric IDs with human-readable slugs in all public player URLs (`/players/:slug`).

**Architecture:** Add a `slug` column to `players`, include the `Sluggable` concern (from vm-t11) with `slug_source :name`, update routes to `param: :slug`, update controllers/services to look up by slug, and update `AutolinkPlayersInNewsService` to emit slug-based URLs instead of ID-based ones.

**Tech Stack:** Rails 8.1, Ruby 4.0.1, RSpec, Sluggable concern, CyrillicTransliterator

---

### Task 1: Migration — add slug column with unique index

**Files:**
- Create: `db/migrate/20260412000001_add_slug_to_players.rb`

- [ ] **Step 1: Generate the migration**

Run:
```bash
bin/rails generate migration AddSlugToPlayers slug:string:uniq
```

- [ ] **Step 2: Edit the migration to make slug nullable initially**

The migration should look like:

```ruby
class AddSlugToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :slug, :string
    add_index :players, :slug, unique: true
  end
end
```

Note: slug is nullable at first. We'll backfill, then add NOT NULL in a later migration.

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: migration succeeds, `schema.rb` shows `slug` column on `players` table.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_slug_to_players.rb db/schema.rb
git commit -m "vm-50: Add nullable slug column with unique index to players"
```

---

### Task 2: Data migration — backfill slugs for existing players

**Files:**
- Create: `db/migrate/20260412000002_backfill_player_slugs.rb`

- [ ] **Step 1: Create the data migration**

```ruby
class BackfillPlayerSlugs < ActiveRecord::Migration[8.1]
  def up
    Player.where(slug: nil).find_each do |player|
      base = CyrillicTransliterator.call(player.name.to_s).parameterize.presence ||
             SecureRandom.hex(2)
      candidate = base
      Sluggable::MAX_SLUG_ATTEMPTS.times do
        unless Player.where.not(id: player.id).exists?(slug: candidate)
          player.update_column(:slug, candidate)
          break
        end
        candidate = "#{base}-#{SecureRandom.hex(Sluggable::TAIL_BYTES)}"
      end
      player.update_column(:slug, candidate) if player.slug.nil?
    end
  end

  def down
    Player.update_all(slug: nil)
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: All players now have slugs. Verify:

```bash
bin/rails runner "puts Player.where(slug: nil).count"
```

Expected output: `0`

- [ ] **Step 3: Commit**

```bash
git add db/migrate/*_backfill_player_slugs.rb db/schema.rb
git commit -m "vm-50: Backfill slugs for existing players"
```

---

### Task 3: Migration — make slug NOT NULL

**Files:**
- Create: `db/migrate/20260412000003_make_player_slug_not_null.rb`

- [ ] **Step 1: Create the NOT NULL migration**

```ruby
class MakePlayerSlugNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :players, :slug, false
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `schema.rb` shows `t.string "slug", null: false` for players.

- [ ] **Step 3: Commit**

```bash
git add db/migrate/*_make_player_slug_not_null.rb db/schema.rb
git commit -m "vm-50: Make player slug NOT NULL"
```

---

### Task 4: Player model — include Sluggable concern

**Files:**
- Modify: `app/models/player.rb`
- Test: `spec/models/player_spec.rb`
- Modify: `spec/factories/players.rb`

- [ ] **Step 1: Write the failing tests**

Add to `spec/models/player_spec.rb` inside the top-level `RSpec.describe Player`:

```ruby
describe "slug" do
  describe "generation" do
    it "generates a slug from name on create" do
      player = create(:player, name: "Алексей")
      expect(player.slug).to eq("aleksey")
    end

    it "generates an ASCII slug from Latin name" do
      player = create(:player, name: "John Doe")
      expect(player.slug).to eq("john-doe")
    end

    it "appends hex tail on collision" do
      create(:player, name: "Алексей")
      duplicate = create(:player, name: "Алексей Другой")
      duplicate.update_column(:slug, nil)
      duplicate.update_column(:name, "Алексей")

      # Force regeneration by clearing slug and re-validating
      duplicate.slug = nil
      duplicate.valid?
      expect(duplicate.slug).to start_with("aleksey-")
      expect(duplicate.slug).not_to eq("aleksey")
    end

    it "does not change slug when name is updated" do
      player = create(:player, name: "Алексей")
      original_slug = player.slug
      player.update!(name: "Борис")
      expect(player.slug).to eq(original_slug)
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      player = create(:player, name: "Алексей")
      expect(player.to_param).to eq(player.slug)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/player_spec.rb --tag slug -f doc`
Expected: FAIL — Player does not include Sluggable yet.

- [ ] **Step 3: Update the Player model**

Add `include Sluggable` and `slug_source :name` to `app/models/player.rb`:

```ruby
class Player < ApplicationRecord
  include Sluggable
  slug_source :name

  has_many :game_participations, dependent: :restrict_with_error
  # ... rest unchanged
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/player_spec.rb -f doc`
Expected: all pass.

- [ ] **Step 5: Run rubocop**

Run: `bundle exec rubocop app/models/player.rb spec/models/player_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/models/player.rb spec/models/player_spec.rb
git commit -m "vm-50: Include Sluggable in Player model with slug_source :name"
```

---

### Task 5: Route — add `param: :slug` to players resource

**Files:**
- Modify: `config/routes.rb:49-52`

- [ ] **Step 1: Update routes**

Change lines 49–52 in `config/routes.rb` from:

```ruby
  resources :players, only: [ :show ] do
    resource :claim, only: [ :create ], controller: "player_claims"
    resource :dispute, only: [ :new, :create ], controller: "player_disputes"
  end
```

to:

```ruby
  resources :players, only: [ :show ], param: :slug do
    resource :claim, only: [ :create ], controller: "player_claims"
    resource :dispute, only: [ :new, :create ], controller: "player_disputes"
  end
```

- [ ] **Step 2: Verify route generation**

Run:
```bash
bin/rails routes -g player
```

Expected: routes show `/players/:slug`, `/players/:player_slug/claim`, `/players/:player_slug/dispute/new`, `/players/:player_slug/dispute`.

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "vm-50: Add param: :slug to players routes"
```

---

### Task 6: Controllers and service — look up by slug

**Files:**
- Modify: `app/controllers/players_controller.rb:3`
- Modify: `app/services/player_profile_service.rb:7-16`
- Modify: `app/controllers/player_claims_controller.rb:7`
- Modify: `app/controllers/player_disputes_controller.rb:7,11`

- [ ] **Step 1: Write failing request spec for 404 on unknown slug**

Add to `spec/requests/players_spec.rb` at the end, inside the top-level describe:

```ruby
context "when player does not exist" do
  it "returns 404 for unknown slug" do
    expect { get player_path(slug: "nonexistent-slug") }
      .to raise_error(ActiveRecord::RecordNotFound)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/players_spec.rb -e "unknown slug"`
Expected: Might pass or fail depending on current lookup — either way confirms the route works.

- [ ] **Step 3: Update PlayersController**

Change `app/controllers/players_controller.rb` from:

```ruby
result = PlayerProfileService.call(player_id: params[:id])
```

to:

```ruby
result = PlayerProfileService.call(player_slug: params[:slug])
```

- [ ] **Step 4: Update PlayerProfileService**

Change `app/services/player_profile_service.rb`:

Replace the `self.call` method, `initialize`, and `Player.find` lookup:

```ruby
def self.call(player_slug:)
  new(player_slug).call
end

def initialize(player_slug)
  @player_slug = player_slug
end

def call
  player = Player.find_by!(slug: @player_slug)
  # ... rest unchanged
end
```

- [ ] **Step 5: Update PlayerClaimsController**

Change `app/controllers/player_claims_controller.rb:7` from:

```ruby
player = Player.find(params[:player_id])
```

to:

```ruby
player = Player.find_by!(slug: params[:player_slug])
```

- [ ] **Step 6: Update PlayerDisputesController**

Change `app/controllers/player_disputes_controller.rb:7` and `:11` from:

```ruby
@player = Player.find(params[:player_id])
```

to:

```ruby
@player = Player.find_by!(slug: params[:player_slug])
```

(Both `new` and `create` actions.)

- [ ] **Step 7: Run all player-related request specs**

Run:
```bash
bundle exec rspec spec/requests/players_spec.rb spec/requests/player_claims_spec.rb spec/requests/player_disputes_spec.rb -f doc
```

Expected: All pass. The specs already use `player_path(player)`, and `to_param` now returns the slug, so route helpers automatically generate `/players/:slug`. The controllers now look up by slug.

- [ ] **Step 8: Run rubocop**

Run:
```bash
bundle exec rubocop app/controllers/players_controller.rb app/controllers/player_claims_controller.rb app/controllers/player_disputes_controller.rb app/services/player_profile_service.rb
```

- [ ] **Step 9: Commit**

```bash
git add app/controllers/players_controller.rb app/controllers/player_claims_controller.rb app/controllers/player_disputes_controller.rb app/services/player_profile_service.rb spec/requests/players_spec.rb
git commit -m "vm-50: Look up players by slug in controllers and service"
```

---

### Task 7: AutolinkPlayersInNewsService — emit slug-based URLs

**Files:**
- Modify: `app/services/autolink_players_in_news_service.rb:50-53,101-103`
- Test: `spec/services/autolink_players_in_news_service_spec.rb`

- [ ] **Step 1: Update the failing spec expectations**

The spec at `spec/services/autolink_players_in_news_service_spec.rb` has ~30 hardcoded `/players/#{alex.id}` references. These all need to change to `/players/#{alex.slug}` (and similarly for `alex_smith`, `ivan`, etc.).

Replace all occurrences of `"/players/#{alex.id}"` with `"/players/#{alex.slug}"` throughout the spec.
Replace all occurrences of `"/players/#{alex_smith.id}"` with `"/players/#{alex_smith.slug}"`.
Replace all occurrences of `"/players/#{ivan.id}"` with `"/players/#{ivan.slug}"`.

Also update the dynamic player references:
- Line 153: `"/players/#{dotted.id}"` → `"/players/#{dotted.slug}"`
- Line 154: same
- Line 183–184: `"/players/#{pot.id}"` → `"/players/#{pot.slug}"`
- Line 191–192: same
- Line 199–200: `"/players/#{team.id}"` → `"/players/#{team.slug}"`
- Line 207–208: same

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/services/autolink_players_in_news_service_spec.rb`
Expected: FAIL — the service still generates `/players/#{id}`.

- [ ] **Step 3: Update `players_by_length_desc` to pluck slug**

Change `app/services/autolink_players_in_news_service.rb:50-53` from:

```ruby
def players_by_length_desc
  Player.pluck(:id, :name)
        .sort_by { |_id, name| -name.length }
        .map { |id, name| [ id, PlayerNameRegex.build(name) ] }
end
```

to:

```ruby
def players_by_length_desc
  Player.pluck(:id, :name, :slug)
        .sort_by { |_id, name, _slug| -name.length }
        .map { |id, name, slug| [ id, slug, PlayerNameRegex.build(name) ] }
end
```

- [ ] **Step 4: Update callers to pass slug through the pipeline**

The pipeline passes `(id, regex)` tuples. Now it passes `(id, slug, regex)` tuples. Update all destructuring:

In `collect_matches` (line 66), change:

```ruby
raw = players.filter_map do |id, regex|
  next if linked_ids.include?(id)

  match = regex.match(text)
  next unless match

  [ match.begin(0), match.end(0), id, match[0] ]
end
```

to:

```ruby
raw = players.filter_map do |id, slug, regex|
  next if linked_ids.include?(id)

  match = regex.match(text)
  next unless match

  [ match.begin(0), match.end(0), id, slug, match[0] ]
end
```

In `drop_overlaps` (line 77), update destructuring:

```ruby
matches.each do |match|
  start, finish, _id, _slug, _matched = match
  next if start < last_end

  result << match
  last_end = finish
end
```

In `link_matches_in_node` (line 56), update destructuring:

```ruby
matches.each { |_start, _finish, id, _slug, _matched| linked_ids << id }
```

In `replace_node_with_matches` (line 92), update destructuring:

```ruby
cursor = matches.reduce(0) do |pos, (start, finish, _id, slug, matched)|
  text_node.add_previous_sibling(doc.create_text_node(text[pos...start]))
  text_node.add_previous_sibling(build_anchor(doc, slug, matched))
  finish
end
```

In `build_anchor` (line 101), change the parameter and URL:

```ruby
def build_anchor(doc, slug, matched)
  anchor = Nokogiri::XML::Node.new("a", doc)
  anchor["href"] = "/players/#{slug}"
  anchor.add_child(doc.create_text_node(matched))
  anchor
end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec rspec spec/services/autolink_players_in_news_service_spec.rb -f doc`
Expected: All pass.

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop app/services/autolink_players_in_news_service.rb spec/services/autolink_players_in_news_service_spec.rb`

- [ ] **Step 7: Commit**

```bash
git add app/services/autolink_players_in_news_service.rb spec/services/autolink_players_in_news_service_spec.rb
git commit -m "vm-50: AutolinkPlayersInNewsService emits slug-based URLs"
```

---

### Task 8: Full test suite + mutation testing

**Files:** None (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bundle exec rspec`
Expected: All green.

- [ ] **Step 2: Run evilution on Player model**

Run: `bundle exec evilution run app/models/player.rb`
Expected: high kill score. Fix any surviving mutants.

- [ ] **Step 3: Run evilution on AutolinkPlayersInNewsService**

Run: `bundle exec evilution run app/services/autolink_players_in_news_service.rb`
Expected: high kill score. Fix any surviving mutants.

- [ ] **Step 4: Run mutant on Player**

Run: `bundle exec mutant run --jobs 1 -- 'Player'`
Expected: high kill score.

- [ ] **Step 5: Run mutant on AutolinkPlayersInNewsService**

Run: `bundle exec mutant run --jobs 1 -- 'AutolinkPlayersInNewsService'`
Expected: high kill score.

- [ ] **Step 6: Run mutant on PlayerProfileService**

Run: `bundle exec mutant run --jobs 1 -- 'PlayerProfileService'`
Expected: high kill score.

- [ ] **Step 7: Commit any mutation-killing test fixes**

```bash
git add -A
git commit -m "vm-50: Fix surviving mutants in player slug implementation"
```

---

### Task 9: Importer re-run verification

**Files:** None (manual verification)

- [ ] **Step 1: Verify import rake task is compatible**

The importer at `lib/tasks/import.rake:220` uses `Player.find_or_initialize_by(id:)` then `player.save!`. Since `Sluggable` auto-generates a slug when `slug.blank?`, new players will get slugs automatically. Re-runs are idempotent because `should_generate_slug?` returns `false` when slug is already present.

Run against the test/dev database to confirm no errors:
```bash
bin/rails runner "p = Player.find_or_initialize_by(id: 99999); p.name = 'Test Import'; p.save!; puts p.slug; p.destroy!"
```

Expected: creates player with auto-generated slug, then cleans up.
