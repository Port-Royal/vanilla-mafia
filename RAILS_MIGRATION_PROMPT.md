# Vanilla Mafia: Ruby on Rails Rewrite — AI Agent Prompt

## Project Overview

You are tasked with rewriting **Chimafia** — a mafia game rating and statistics tracking web application — from PHP/Yii2 to **Ruby on Rails 8.1**. The original project suffers from numerous security vulnerabilities, architectural problems, zero test coverage, and poor separation of concerns. This rewrite is a greenfield opportunity to build the system correctly from the ground up.

The application tracks mafia game sessions organized into **seasons** and **series**, records per-player-per-game ratings (role, win/loss, point scores, bonuses), computes aggregated statistics, manages player awards, and provides a public-facing website and an admin panel for data management.

### Project Paths

| | Path |
|---|------|
| **This prompt** | Copy this file into the new Rails project root before starting |
| **Old PHP project** | `../chimafia/` (relative to the new Rails project) |
| **Old models** | `../chimafia/chimafia/models/` |
| **Old controllers** | `../chimafia/chimafia/controllers/SiteController.php` |
| **Old views** | `../chimafia/chimafia/views/site/` |
| **Old migrations** | `../chimafia/chimafia/migrations/` |
| **Old DB config** | `../chimafia/chimafia/config/` |
| **Old admin config** | `../chimafia/chimafia/config/admin.php` |
| **Webix extension** | `../chimafia/webix/` |
| **Base library** | `../chimafia/library/` |

When you need to reference the original implementation (e.g., to extract the extra points formula from a database view, or to understand a specific behavior), read files from the old project paths above. Do NOT modify the old project.

---

## Task Management: Use Beads

All work on this project **must** be tracked using the [Beads (`bd`)](https://github.com/steveyegge/beads) distributed issue tracker. Before writing any code:

1. Initialize beads in the project root: `bd init`
2. Create an epic for each major domain area (see "Implementation Phases" below)
3. Break epics into tasks and subtasks with clear dependency chains using `bd dep add`
4. Before starting work on any task, run `bd ready` to find unblocked tasks
5. Claim tasks with `bd update <id> --claim` before beginning
6. Mark tasks completed when done; beads will auto-unblock dependents
7. Use `bd show <id>` to review task history and decisions

### Beads Workflow Rules

- Every feature branch should reference the beads task ID in the commit message
- When a task reveals new sub-work, create child tasks (e.g., `bd-a3f8.1.1`)
- Use `relates_to` links between cross-cutting concerns (e.g., auth tasks relate to admin tasks)
- Periodically run beads compaction to summarize completed work and keep context manageable
- Use `bd create "Task title" -p <priority>` with priorities: 0 (critical), 1 (high), 2 (medium), 3 (low)

---

## AI Agent Tooling: Claude-on-Rails + SwarmSDK

This project should be developed using **[claude-on-rails](https://github.com/obie/claude-on-rails)** — a gem that orchestrates a team of specialized Claude agents for Rails development — backed by **[SwarmSDK](https://github.com/parruda/swarm)** for multi-agent coordination.

### Setup

```bash
# Add to Gemfile
group :development do
  gem 'claude-on-rails'
end

bundle install
rails generate claude_on_rails:swarm
```

This generates:
- `claude-swarm.yml` — agent team configuration
- `CLAUDE.md` — project-level Claude instructions (merge with this prompt's architectural principles)
- `.claude-on-rails/prompts/` — per-agent instruction files

Then set up Rails MCP Server for documentation access:
```bash
bundle exec rake claude_on_rails:setup_mcp
```

### Agent Team

Claude-on-Rails provides 7 specialized agents that map directly to this project's needs:

| Agent | Role in Vanilla Mafia |
|-------|--------------------------|
| **Architect** | Enforces the architectural principles from this prompt: thin controllers, service objects, no raw SQL in controllers, proper separation of concerns |
| **Models** | Creates migrations with foreign keys and indexes, implements ActiveRecord models with validations/associations/scopes as specified in the schema section |
| **Controllers** | Builds the RESTful controllers (SeasonsController, GamesController, PlayersController, SeriesController, HallOfFameController, Admin::*) |
| **Views** | Implements responsive Tailwind CSS layouts, replaces the original table-based layout with semantic HTML5 |
| **Services** | Builds SeasonOverviewService, PlayerProfileService, SeriesAggregationService, HallOfFameService |
| **Tests** | Writes acceptance tests first (ATDD), model specs, request specs, policy specs — targeting 95%+ coverage |
| **DevOps** | Sets up Dockerfile, docker-compose.yml, GitHub Actions CI, Rails encrypted credentials |

### Customizing Agent Prompts

After generation, edit `.claude-on-rails/prompts/` to encode project-specific rules:

**`.claude-on-rails/prompts/models.md`** — add:
```
- Use standard Rails table names (no t_, d_, v_, ref_ prefixes)
- All foreign keys must have database-level constraints and indexes
- Use Active Storage for images (player photos, award icons)
- Use decimal(5,2) for rating points, not float
- Implement extra_points calculation as a model method, not a DB view
```

**`.claude-on-rails/prompts/tests.md`** — add:
```
- Every feature starts with an acceptance test (Capybara)
- Use FactoryBot for all test data — no fixtures, no hardcoded data
- Target 95%+ coverage (SimpleCov)
- Test authorization policies with Pundit matchers
- Test all model validations and associations with Shoulda Matchers
```

**`.claude-on-rails/prompts/architect.md`** — add:
```
- Never allow raw SQL in controllers — delegate to scopes or query objects
- All user-facing strings must go through I18n (locale: :ru)
- No hardcoded credentials — use Rails encrypted credentials
- Authentication via Devise, authorization via Pundit
- Review the "36 Problems" section of this project's RAILS_MIGRATION_PROMPT.md before every decision
```

### SwarmSDK for Advanced Workflows

For more complex orchestration (e.g., multi-stage migration pipelines), use SwarmSDK directly with node workflows:

```yaml
# vanilla-mafia-swarm.yml
version: 2
plugins:
  - swarm_memory:
      storage_dir: ./memories

agents:
  lead:
    model: claude-sonnet-4-5-20250929
    role: "Lead architect coordinating the Vanilla Mafia Rails project"
    tools: [Read, Write, Edit, Bash, MemoryWrite, MemoryRead]
    delegates_to: [backend, frontend, qa]

  backend:
    model: claude-sonnet-4-5-20250929
    role: "Backend developer: models, migrations, services, controllers"
    tools: [Read, Write, Edit, Bash]

  frontend:
    model: claude-sonnet-4-5-20250929
    role: "Frontend developer: views, Tailwind CSS, responsive design"
    tools: [Read, Write, Edit]

  qa:
    model: claude-sonnet-4-5-20250929
    role: "QA engineer: ATDD acceptance tests, model specs, request specs"
    tools: [Read, Write, Edit, Bash]

hooks:
  on_user_message:
    - run: "bd ready"
      append_output_to_context: true
```

The `on_user_message` hook automatically feeds the current beads task queue into every agent interaction, keeping agents aware of what's ready to work on.

### Integration with Beads

Both tools complement beads:
- **Beads** tracks *what* needs to be done (tasks, dependencies, priorities)
- **Claude-on-Rails / SwarmSDK** handles *who* does it (which specialized agent) and *how* (with Rails-aware context)
- The `bd ready` hook ensures agents always pick up the highest-priority unblocked task

---

## Development Methodology: ATDD (Acceptance Test-Driven Development)

The original project has **zero tests**. This rewrite follows strict ATDD:

### ATDD Cycle for Every Feature

1. **Write an acceptance test first** (RSpec + Capybara for UI features, RSpec request specs for API endpoints)
2. **Watch it fail** — confirm the test fails for the right reason
3. **Write the minimal implementation** to make the test pass
4. **Refactor** while keeping tests green
5. **Repeat** for the next acceptance criterion

### Testing Stack

- **RSpec** — primary test framework
- **Capybara** — browser-level acceptance tests
- **FactoryBot** — test data factories (replace every hardcoded fixture)
- **Shoulda Matchers** — model validation and association specs
- **DatabaseCleaner** — clean state between tests
- **SimpleCov** — code coverage tracking (target: 95%+)
- **VCR or WebMock** — for any external API interactions

### Test Organization

```
spec/
├── acceptance/          # High-level user journey tests (Capybara)
│   ├── viewing_season_spec.rb
│   ├── viewing_game_details_spec.rb
│   ├── viewing_player_profile_spec.rb
│   ├── viewing_series_totals_spec.rb
│   ├── hall_of_fame_spec.rb
│   └── admin/
│       ├── managing_players_spec.rb
│       ├── managing_games_spec.rb
│       ├── managing_ratings_spec.rb
│       └── managing_awards_spec.rb
├── requests/            # API / controller-level request specs
├── models/              # Unit tests for models, validations, scopes
├── services/            # Unit tests for service objects
├── policies/            # Authorization policy specs
├── factories/           # FactoryBot factory definitions
└── support/             # Shared contexts, helpers
```

---

## Original Application: Feature Specification

### Domain Model

The application models a **mafia game club** with the following entities:

#### Players
- Name, optional comment/bio, display photo, display order (`flow`)
- Participate in games across multiple seasons
- Receive awards (regular and staff/organizer badges)
- Have computed statistics: total rating, games played, wins, win rate — per season

#### Games
- Belong to a season (integer), series (integer within season), and game number (within series)
- Have a date, optional name/description, and result
- Contain multiple rating entries (one per player who participated)

#### Ratings (per player per game)
- Role played (references a roles dictionary: e.g., Мирный/Мафия/Дон/Шериф)
- Win/loss (boolean)
- Plus points, minus points (decimal)
- Best move indicator (decimal)
- First shoot indicator (boolean)
- Computed: `total = plus - minus + extra_points`
- Extra points are calculated at the database view level

#### Roles (dictionary)
- Code (primary key) and display name
- e.g., `peace` → "Мирный", `mafia` → "Мафия", `don` → "Дон", `sheriff` → "Шериф"

#### Awards (dictionary)
- Title, image/icon, display order, description
- Staff flag (boolean) — distinguishes organizer badges from player awards
- Assigned to players via a join table with season and display order

#### Players-Awards (join)
- Links players to awards
- Tracks which season the award was given
- Has display ordering

### Database Views (Computed Aggregations)

The original uses PostgreSQL views for computed data. In Rails, implement these as:

#### Player Statistics (replaces `v_players`)
- Per-player, per-season aggregation
- Fields: games count, wins count, total rating, extra points
- Derived: win_rate = (wins / games) * 100
- **Implementation**: Use scopes, computed columns, or materialized views — NOT raw SQL in controllers

#### Rating with Totals (replaces `v_rating`)
- Per-rating record with computed total
- Fields: total = plus - minus + extra_points
- **Implementation**: Virtual attribute on the Rating model or database-level computed column

### Public Pages

1. **Season Overview** (`/` redirects to current season, `/seasons/:number`)
   - Section 1: Games grouped by series — each row shows date, series link, individual game links
   - Section 2: Player rankings — sorted by total rating (desc), wins (desc), games (desc), name (asc)
   - Columns: rank, player name (linked), rating total, games played, win percentage

2. **Game Details** (`/games/:id`)
   - Game header: full name (date, season, series, game number, custom name)
   - Rating table: all players in that game with role, win, plus, minus, best move, extra points, first shoot, total

3. **Player Profile** (`/players/:id`)
   - Player photo (with fallback placeholder)
   - Per-season breakdown: season stats (total, win%) + list of games with individual ratings
   - Awards section: regular awards and staff badges displayed separately

4. **Series Totals** (`/seasons/:season/series/:series`)
   - Matrix table: rows = players, columns = individual games + total
   - Cells = rating points per game
   - Sorted by total descending

5. **Hall of Fame** (`/hall`)
   - Awarded players with photos in decorative frames + their awards
   - All award descriptions section
   - Staff/organizer section (separate from regular players)

### Admin Panel

The original uses a Webix (JavaScript UI library) based admin panel. In Rails, replace with:

- **ActiveAdmin** or **Administrate** or **Avo** — choose one modern Rails admin framework
- Full CRUD for: Players, Games, Ratings, Awards, Player-Awards assignments
- Nested forms: Games → Ratings (manage ratings inline when editing a game)
- Image upload for players and awards (use **Active Storage**)
- Proper authentication and authorization on all admin routes

### Authentication & Authorization

The original has **critical security failures** here (see Problems section). Build properly:

- **Devise** for authentication (database-backed users, bcrypt password hashing)
- **Pundit** for authorization policies
- Admin users only — no public registration (invite-only or seed-based)
- Separate admin role with explicit policy checks on every admin action

---

## Problems in the Original Code: DO NOT REPRODUCE

### CRITICAL SECURITY VULNERABILITIES

1. **Hardcoded database credentials** in `config/db.php` — plaintext password `pikvaYhaigel42` committed to source control
   - **FIX**: Use Rails encrypted credentials (`rails credentials:edit`) or environment variables via `dotenv-rails`. Never commit secrets.

2. **Hardcoded API keys** in `config/console.php` — Discogs API key and secret in plaintext
   - **FIX**: All third-party API keys go into Rails encrypted credentials.

3. **MD5 password hashing** — the `User` model validates passwords with raw MD5 comparison, no salt
   - **FIX**: Use Devise with bcrypt (default). Never implement custom password hashing.

4. **Hardcoded user accounts** — 4 users with MD5 password hashes defined as a PHP array in the User model, not stored in a database
   - **FIX**: Database-backed user model with Devise. Seed initial admin users via `db/seeds.rb`.

5. **Cookie validation key exposed** in source control — `6v-zj8DTvRxZTLvu3NW-2E4UQRRAY7f9`
   - **FIX**: Rails handles secret_key_base via credentials. Never commit it.

6. **No authentication on admin routes** — the admin panel has no visible auth guard; it appears to rely on the web server for protection
   - **FIX**: Devise `authenticate_admin_user!` before_action on all admin controllers. Pundit policies on every action.

7. **Debug mode conditionally enabled via cookie** — setting an `xyii-debug` cookie enables debug toolbar in production
   - **FIX**: Debug tools only in development/test environments. Never allow user-controlled debug activation.

8. **No CSRF protection visible** on admin API endpoints — the Webix REST controllers extend `yii\rest\ActiveController` which may bypass CSRF
   - **FIX**: Rails has CSRF protection by default. Keep it enabled. For API endpoints, use token-based authentication.

9. **Arbitrary class instantiation via GET parameter** — the custom `xr/webix` admin framework's `DataController` accepts a `model` class name directly from a GET parameter and instantiates it (`?model=app-models-Player` becomes `app\models\Player`). This is a **remote code execution vector** — an attacker could instantiate arbitrary classes.
   - **FIX**: Use a whitelist/registry of allowed admin resources. Never instantiate classes from user input. Rails admin frameworks (ActiveAdmin, Administrate, Avo) handle this correctly by declaring resources explicitly.

10. **No file upload validation on the server** — the upload controller in `xr/webix` checks file extensions but does not validate MIME types or file content, allowing potential malicious file upload
    - **FIX**: Use Active Storage with proper content-type validation. Validate both extension and MIME type. Store uploads outside the web root.

### ARCHITECTURAL PROBLEMS

11. **God Controller** — `SiteController` is the only controller, containing ALL business logic, complex data transformations, raw SQL queries, and view data preparation for 6+ different page types
   - **FIX**: One controller per resource. Extract business logic into service objects. Controllers should only coordinate between request, service, and response.

   ```ruby
   # Good structure:
   app/controllers/
   ├── seasons_controller.rb      # index, show
   ├── games_controller.rb        # show
   ├── players_controller.rb      # show
   ├── series_controller.rb       # show
   └── hall_of_fame_controller.rb # show
   ```

12. **Raw SQL in controllers** — queries like `string_agg(id::text, ',')` directly in controller actions, making the code PostgreSQL-dependent and untestable
    - **FIX**: Use ActiveRecord scopes, query objects, or service objects. Keep SQL in the model layer. If raw SQL is necessary, encapsulate it in a clearly named scope or query object.

13. **Business logic in views** — views perform data processing, conditional calculations, and complex iterations that belong in presenters or helpers
    - **FIX**: Use ViewComponent or presenter/decorator pattern. Views should only render pre-computed data.

14. **No service layer** — all data fetching, transformation, sorting, and aggregation happens inline in controller actions
    - **FIX**: Create service objects for complex operations:
    ```ruby
    app/services/
    ├── season_statistics_service.rb
    ├── player_profile_service.rb
    ├── series_aggregation_service.rb
    └── hall_of_fame_service.rb
    ```

15. **No dependency injection** — components are tightly coupled via static calls and global state (`Yii::$app->`)
    - **FIX**: Pass dependencies explicitly. Use Rails conventions and constructor injection in service objects.

16. **Model naming inconsistencies** — `Games` (plural) model for a single record, `Player` (singular) is correct; `Rating` model class and `view/Rating` model class share the same name in different namespaces causing confusion
    - **FIX**: Follow Rails conventions strictly: singular model names (`Game`, `Player`, `Rating`, `Award`, `Role`). Use clear namespacing or distinct names for read models if needed.

17. **Ambiguous table prefix convention** — `t_`, `d_`, `v_`, `ref_` prefixes are non-standard and create friction
    - **FIX**: Use standard Rails table naming: `players`, `games`, `ratings`, `roles`, `awards`, `players_awards`. No prefixes.

### DATABASE PROBLEMS

18. **No foreign key constraints visible** — relationships defined only at the ORM level, not enforced at the database
    - **FIX**: Add `foreign_key: true` to all `references` in migrations. Use `add_foreign_key` explicitly.

19. **Missing database indexes** — no evidence of indexes on foreign keys or frequently queried columns
    - **FIX**: Add indexes on all foreign keys, and on columns used in WHERE/ORDER BY (e.g., `season`, `series`, `game_id`, `player_id`).

20. **Migrations not in version control** — exist only in git history, not reliably reproducible
    - **FIX**: All migrations committed, `db/schema.rb` always up to date. Use `rails db:migrate` as part of CI.

21. **Database views for simple aggregations** — PostgreSQL views used where ActiveRecord scopes or computed attributes would suffice, creating tight database coupling
    - **FIX**: Prefer ActiveRecord calculations (`.sum`, `.count`, `.group`) and scopes. Use database views only for genuinely complex aggregations that benefit from DB-level optimization, and wrap them in read-only models.

### CODE QUALITY PROBLEMS

22. **Zero test coverage** — Codeception configured but no tests written
    - **FIX**: ATDD from the start. No feature ships without acceptance tests. See Testing section above.

23. **Magic strings everywhere** — table names, role codes, column names as raw strings throughout the codebase
    - **FIX**: Use constants, enums (`ActiveRecord::Enum`), or configuration objects.

24. **No input validation on public routes** — controller actions accept `$id`, `$season`, `$series` parameters without type checking or bounds validation
    - **FIX**: Use strong parameters. Validate and type-cast all route parameters. Use `find` (which raises `RecordNotFound`) instead of `findOne` (which silently returns null).

25. **No error handling** — missing records, invalid parameters, and database errors will produce raw stack traces
    - **FIX**: Implement proper error pages (404, 422, 500). Use `rescue_from` in ApplicationController. Custom error views.

26. **Legacy/dead code** — Discogs API component configured but never used in the current app; it's from a previous project ("vinylnice") that was apparently repurposed
    - **FIX**: Do not include any unused integrations. Build only what's needed.

27. **No pagination on public pages** — all players/games loaded at once
    - **FIX**: Use `kaminari` or `pagy` for pagination on lists that could grow.

### FRONTEND PROBLEMS

28. **Table-based layout** — the entire page layout uses `<table>` elements for positioning (not data tables)
    - **FIX**: Use semantic HTML5 with CSS Grid/Flexbox. Or use a component framework like Tailwind CSS or Bootstrap 5.

29. **Not responsive** — fixed widths (984px content, 225px sidebar) with no mobile support
    - **FIX**: Mobile-first responsive design. Test at multiple breakpoints.

30. **No CSS framework** — custom raw CSS with no methodology (no BEM, no utility classes)
    - **FIX**: Use Tailwind CSS (recommended for Rails 8) or Bootstrap 5. Consistent design system.

31. **Inline styles and mixed concerns** — CSS rules mixed with layout, no component structure
    - **FIX**: Component-based styling. Use ViewComponent for reusable UI elements.

32. **No asset pipeline optimization** — CSS with manual version suffixes (`style.css?v9`), no minification
    - **FIX**: Rails asset pipeline (Propshaft in Rails 8) or import maps handle this automatically.

### DEPLOYMENT/DEVOPS PROBLEMS

33. **No containerization** — Vagrant-based development environment only
    - **FIX**: Provide `Dockerfile` and `docker-compose.yml` for development and production.

34. **No CI/CD** — no automated builds, tests, or deployments
    - **FIX**: GitHub Actions workflow: lint, test, security scan on every PR.

35. **Environment-specific logic in entry point** — `web/index.php` checks `$_SERVER['SERVER_NAME']` to set debug mode
    - **FIX**: Use Rails environments (`development`, `test`, `production`). No runtime environment detection.

36. **Hardcoded locale** — Russian language hardcoded throughout views and configuration
    - **FIX**: Use Rails I18n from the start. All user-facing strings in `config/locales/ru.yml`. Default locale set to `:ru`.

---

## Database Schema for Rails

### Migrations to Create

```ruby
# Players
create_table :players do |t|
  t.string :name, null: false
  t.text :comment
  t.integer :position  # display ordering (was "flow")
  t.timestamps
end

# Roles (dictionary)
create_table :roles do |t|
  t.string :code, null: false, index: { unique: true }
  t.string :name, null: false
end

# Games
create_table :games do |t|
  t.date :played_on          # was "date" — avoid reserved words
  t.integer :season, null: false
  t.integer :series, null: false
  t.integer :game_number, null: false  # was "game"
  t.string :name
  t.string :result
  t.timestamps
end
add_index :games, [:season, :series, :game_number], unique: true
add_index :games, :season
add_index :games, [:season, :series]

# Ratings
create_table :ratings do |t|
  t.references :game, null: false, foreign_key: true
  t.references :player, null: false, foreign_key: true
  t.string :role_code
  t.boolean :first_shoot, default: false
  t.boolean :win, default: false
  t.decimal :plus, precision: 5, scale: 2, default: 0
  t.decimal :minus, precision: 5, scale: 2, default: 0
  t.decimal :best_move, precision: 5, scale: 2
  t.timestamps
end
add_index :ratings, [:game_id, :player_id], unique: true
add_foreign_key :ratings, :roles, column: :role_code, primary_key: :code

# Awards (dictionary)
create_table :awards do |t|
  t.string :title, null: false
  t.integer :position          # display ordering (was "flow")
  t.boolean :staff, default: false
  t.text :description
  t.timestamps
end

# Players-Awards (join table)
create_table :player_awards do |t|
  t.references :player, null: false, foreign_key: true
  t.references :award, null: false, foreign_key: true
  t.integer :season
  t.integer :position          # display ordering
  t.timestamps
end
add_index :player_awards, [:player_id, :award_id, :season], unique: true
```

### Active Storage

Use Active Storage for player photos and award images instead of custom file handling:

```ruby
# Player model
has_one_attached :photo

# Award model
has_one_attached :icon
```

---

## Model Specifications

```ruby
# app/models/player.rb
class Player < ApplicationRecord
  has_many :ratings, dependent: :restrict_with_error
  has_many :games, through: :ratings
  has_many :player_awards, dependent: :destroy
  has_many :awards, through: :player_awards
  has_one_attached :photo

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, name: :asc) }
  scope :with_stats_for_season, ->(season) { ... }  # Encapsulate aggregation logic
end

# app/models/game.rb
class Game < ApplicationRecord
  has_many :ratings, dependent: :destroy
  has_many :players, through: :ratings

  validates :season, :series, :game_number, presence: true, numericality: { only_integer: true }
  validates :game_number, uniqueness: { scope: [:season, :series] }

  scope :for_season, ->(season) { where(season: season) }
  scope :ordered, -> { order(played_on: :asc, series: :asc, game_number: :asc) }

  def full_name
    parts = [played_on&.to_s, "Сезон #{season}", "Серия #{series}", "Игра #{game_number}", name].compact
    parts.join(" ")
  end

  def in_season_name
    "Серия #{series} Игра #{game_number}"
  end
end

# app/models/rating.rb
class Rating < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :role, foreign_key: :role_code, primary_key: :code, optional: true

  validates :game, :player, presence: true
  validates :player_id, uniqueness: { scope: :game_id }
  validates :plus, :minus, numericality: true, allow_nil: true
  validates :best_move, numericality: true, allow_nil: true

  def total
    (plus || 0) - (minus || 0) + extra_points
  end

  def extra_points
    # Implement the extra points calculation logic here
    # (extracted from the original v_rating database view)
    0
  end
end

# app/models/role.rb
class Role < ApplicationRecord
  self.primary_key = :code
  has_many :ratings, foreign_key: :role_code, primary_key: :code

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end

# app/models/award.rb
class Award < ApplicationRecord
  has_many :player_awards, dependent: :restrict_with_error
  has_many :players, through: :player_awards
  has_one_attached :icon

  validates :title, presence: true

  scope :for_players, -> { where(staff: false) }
  scope :for_staff, -> { where(staff: true) }
  scope :ordered, -> { order(position: :asc) }
end

# app/models/player_award.rb
class PlayerAward < ApplicationRecord
  belongs_to :player
  belongs_to :award

  validates :player, :award, presence: true
  validates :award_id, uniqueness: { scope: [:player_id, :season] }

  scope :ordered, -> { order(position: :asc) }
end
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "seasons#show", defaults: { number: 5 }  # Redirect to current season

  resources :seasons, only: [:show], param: :number do
    resources :series, only: [:show], param: :number
  end

  resources :games, only: [:show]
  resources :players, only: [:show]

  get "hall", to: "hall_of_fame#show"

  # Admin (protected)
  namespace :admin do
    root "dashboard#index"
    resources :players
    resources :games do
      resources :ratings, only: [:new, :create, :edit, :update, :destroy]
    end
    resources :awards
    resources :player_awards, only: [:create, :destroy]
  end
end
```

---

## Service Objects

Extract complex business logic from controllers:

```ruby
# app/services/season_overview_service.rb
class SeasonOverviewService
  def initialize(season:)
    @season = season
  end

  def call
    {
      series_with_games: load_series_with_games,
      player_rankings: load_player_rankings
    }
  end

  private

  def load_series_with_games
    # Group games by series, ordered by date
    # Return structured data ready for the view
  end

  def load_player_rankings
    # Aggregate player stats for the season
    # Sort by: total desc, wins desc, games desc, name asc
    # Return array of player stat structs
  end
end

# app/services/series_aggregation_service.rb
class SeriesAggregationService
  # Build the player × game matrix for a series
end

# app/services/player_profile_service.rb
class PlayerProfileService
  # Load player with per-season stats, game history, and awards
end

# app/services/hall_of_fame_service.rb
class HallOfFameService
  # Load awarded players grouped by type (regular vs staff)
end
```

---

## Implementation Phases

### Phase 1: Project Setup & Core Models (Priority 0)
1. Initialize Rails 8 app with SQLite
2. Initialize beads: `bd init`
3. Configure RSpec, FactoryBot, Capybara, SimpleCov
4. Configure Devise for admin authentication
5. Configure Pundit for authorization
6. Configure I18n with Russian locale
7. Create all database migrations with proper constraints and indexes
8. Create all models with validations, associations, and scopes
9. Write model specs (validations, associations, scopes, computed attributes)
10. Seed roles dictionary and sample data

### Phase 2: Public Pages (Priority 0)
1. Write acceptance tests for each public page
2. Implement SeasonsController#show (season overview)
3. Implement GamesController#show (game details)
4. Implement PlayersController#show (player profile)
5. Implement SeriesController#show (series matrix)
6. Implement HallOfFameController#show
7. Build responsive layout with Tailwind CSS
8. Implement service objects for each page's data needs
9. Write request specs for all controllers

### Phase 3: Admin Panel (Priority 1)
1. Set up admin framework (ActiveAdmin, Administrate, or Avo)
2. Write acceptance tests for all admin CRUD operations
3. Implement admin CRUD for Players (with photo upload)
4. Implement admin CRUD for Games (with nested ratings)
5. Implement admin CRUD for Awards (with icon upload)
6. Implement admin management for Player-Award assignments
7. Add Pundit policies for all admin actions
8. Write request specs for admin endpoints

### Phase 4: Polish & Deployment (Priority 2)
1. Error handling (404, 422, 500 pages)
2. Pagination where needed
3. Performance optimization (eager loading, caching, database indexes)
4. Docker configuration (Dockerfile + docker-compose.yml)
5. GitHub Actions CI pipeline (lint + test + security)
6. Production configuration (credentials, logging, caching)
7. Data migration script (rake task) to import data from the old PostgreSQL database (see `../chimafia/chimafia/config/db.php` for connection details)

---

## Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| Framework | Ruby on Rails 8.1+ |
| Ruby | 4.0+ |
| Database | SQLite (Rails 8 default) |
| Auth | Devise |
| Authorization | Pundit |
| Admin | ActiveAdmin or Administrate or Avo |
| File Uploads | Active Storage |
| CSS | Tailwind CSS |
| Testing | RSpec + Capybara + FactoryBot |
| I18n | Rails I18n (default locale: :ru) |
| Task Tracking | Beads (`bd`) |
| Agent Orchestration | claude-on-rails + SwarmSDK |
| CI | GitHub Actions |
| Containers | Docker + docker-compose |

---

## Key Architectural Principles

1. **No raw SQL in controllers** — all queries through ActiveRecord scopes or query objects
2. **Thin controllers** — delegate to service objects for anything beyond simple CRUD
3. **Fat models, but not too fat** — validations, associations, scopes, and simple computed attributes in models; complex business logic in services
4. **Every feature test-driven** — write the acceptance test first, then implement
5. **Security by default** — encrypted credentials, bcrypt passwords, CSRF protection, strong parameters, authorization policies
6. **I18n from day one** — no hardcoded user-facing strings
7. **Responsive design** — mobile-first with Tailwind CSS
8. **Database integrity** — foreign keys, unique constraints, NOT NULL where appropriate, indexes on all queried columns
9. **No dead code** — do not port unused features (Discogs integration, mailer setup that was never used, etc.)
10. **Convention over configuration** — follow Rails conventions for naming, file structure, and patterns
11. **Self-documenting code, no comments** — do NOT add explanatory comments to the code. Write code that explains itself through clear naming of variables, methods, classes, and modules. If a piece of logic needs a comment to be understood, that is a signal to refactor it — extract a well-named method, rename a variable, or simplify the logic. The only acceptable comments are legal headers, TODO markers tied to a beads task ID, and annotations required by tooling (e.g., `# frozen_string_literal: true`)

---

## Locale File Starter

```yaml
# config/locales/ru.yml
ru:
  activerecord:
    models:
      player: "Игрок"
      game: "Игра"
      rating: "Рейтинг"
      award: "Награда"
      role: "Роль"
    attributes:
      player:
        name: "Имя"
        comment: "Комментарий"
        photo: "Фото"
      game:
        played_on: "Дата"
        season: "Сезон"
        series: "Серия"
        game_number: "Номер игры"
        name: "Название"
        result: "Результат"
      rating:
        role_code: "Роль"
        win: "Победа"
        plus: "Плюс"
        minus: "Минус"
        best_move: "Лучший ход"
        first_shoot: "Первый выстрел"
        total: "Итого"
      award:
        title: "Название"
        description: "Описание"
        staff: "Организаторская"
  seasons:
    show:
      by_series: "По сериям и играм"
      by_players: "По игрокам"
      rank: "Место"
      player: "Игрок"
      rating: "Рейтинг"
      games: "Игры"
      win_rate: "Процент побед"
  hall_of_fame:
    title: "Зал Славы"
    organizers: "Организаторы"
    all_awards: "Все награды"
  common:
    season: "Сезон"
    series: "Серия"
    game: "Игра"
    coming_soon: "Скоро! Следите за обновлениями"
```

---

## Extra Points Calculation

The original application computes "extra points" at the database view level. You need to reverse-engineer the exact formula from the old project's database views. The general pattern is:

- Extra points are a bonus applied to ratings based on game-specific conditions
- The `total` field = `plus - minus + extra_points`
- This calculation should be encapsulated in the `Rating` model or a dedicated calculator service, not spread across views or controllers

**To find the formula**: Read the migration file that creates the views at `../chimafia/chimafia/migrations/` (look for `create_views` in the filename, e.g., `m251121_075524_create_views.php`). Also check the view models at `../chimafia/chimafia/models/view/Rating.php` and `../chimafia/chimafia/models/view/Players.php`. Do not guess — extract the exact SQL from these files.

---

## What NOT to Build

- Discogs/vinyl integration (legacy from a different project)
- Mailer functionality (was configured but never used)
- The `HelloController` console command (demo code)
- The custom Webix admin framework (replace with a Rails admin gem)
- File-based caching (use Rails built-in caching strategy)
- Vagrant provisioning (use Docker instead)
- Cookie-based debug mode toggling
