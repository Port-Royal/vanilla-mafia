# Home and Game Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigned home page (#1171) and game page (#1172) in the warm paper look, shown when `new_design?` is true;
the old pages render unchanged otherwise.

**Architecture:** Each controller keeps its data loading and picks the template: `render "home/redesign/index"` /
`render "games/redesign/show"` when `helpers.new_design?`, the existing template otherwise. New markup lives under
`app/views/{home,games}/redesign/`. Shared components (pill, table, medal, label) are opt-in `vm-*` classes in
`app/assets/tailwind/application.css`, built in Task 1 and reused in Task 2.

**Tech Stack:** Rails 8.1, Tailwind v4, RSpec request/helper/model specs with `let_it_be`, evilution.

**Specs:** `docs/superpowers/specs/2026-11-19-home-page-redesign-design.md` (Task 1),
`docs/superpowers/specs/2026-11-19-game-page-redesign-design.md` (Task 2), and the foundation spec
`docs/superpowers/specs/2026-11-18-public-site-foundation-design.md`.

## Global Constraints

- Old pages unchanged: with no `public_redesign` toggle, `spec/requests/home_spec.rb`, `games_spec.rb`,
  `games_hidden_roles_spec.rb` pass untouched.
- New-design specs use `include_context "with the new design"` (`spec/support/new_design.rb`).
- URLs and existing i18n keys stay; every new string in both `ru.yml` and `en.yml`.
- Opt-in styling only: no new rules on bare elements; never use gold `#d9a21b` (`text-gold`) for text; colour utilities
  go directly on elements inside `vm-chrome` areas.
- No `&.`, no `and return`; specs: `let_it_be`/`let`, nested `context`, no variables inside `it`.
- Each task is one PR: TDD, rubocop, `NO_COVERAGE=1 bundle exec evilution run <file> --jobs 1` on changed Ruby,
  results to `.artifacts.local/regular-evilution-feedback.log` only.

## Review Focus

1. A competition with no players yet / a finished competition with no games — the winner and standings lookups must
   not raise; the row shows without a winner. → Task 1.
2. News with photos that aren't variable (e.g. a PDF) — no thumbnail, no error. → Task 1.
3. A game whose `best_move_seats` is set but `best_move` is nil (or the reverse) — show what exists, nothing else.
   → Task 2.
4. Two games of one competition with the same date and number on different tables — neighbour links stay stable and
   never point to the game itself. → Task 2.
5. A game with no `played_on`, judge or table — the meta line omits those parts without stray separators. → Task 2.

---

## File map

| File | Task | Responsibility |
|------|------|----------------|
| `app/assets/tailwind/application.css` | 1 | `vm-pill*`, `vm-table`, `vm-row--highlight`, `vm-sub`, `vm-medal*`, `vm-label` |
| `app/controllers/home_controller.rb` | 1 | pick template; skip unused loads in new design |
| `app/views/home/redesign/index.html.erb` + partials | 1 | new home page |
| `app/helpers/news_helper.rb` | 1 | `:card` photo variant |
| `app/helpers/results_helper.rb` | 1 | `game_result_pill(game)` shared by both pages |
| `app/controllers/games_controller.rb` | 2 | pick template |
| `app/models/game.rb` | 2 | `#previous_in_competition`, `#next_in_competition` |
| `app/helpers/games_helper.rb` | 2 | `format_score`, `score_parts` |
| `app/views/games/redesign/show.html.erb` + partials | 2 | new game page |

Execution: a chain — Task 2 branches from Task 1's branch (it reuses the components). Task 2's PR also adds the game
page design doc, which is not yet on master.

---

### Task 1: Home page and shared components (vm-bpk.2 / #1171)

**Files:**
- Modify: `app/assets/tailwind/application.css`, `app/controllers/home_controller.rb`, `app/helpers/news_helper.rb`,
  `config/locales/ru.yml`, `config/locales/en.yml`
- Create: `app/helpers/results_helper.rb`, `app/views/home/redesign/index.html.erb`,
  `app/views/home/redesign/_event_slot.html.erb`, `_running.html.erb`, `_recently_finished.html.erb`,
  `_recent_games.html.erb`, `_news.html.erb`
- Test: `spec/requests/redesign/home_spec.rb`, `spec/helpers/results_helper_spec.rb`, `spec/helpers/news_helper_spec.rb`

**Interfaces:**
- Produces CSS classes (foundation tokens, `@layer components`):
  - `vm-pill` (inline, `rounded-full`, 11–12 px semibold, `px-2.5 py-0.5`) + `vm-pill--gold` (`bg-gold-soft`,
    text `#5c4000`), `vm-pill--alert` (`bg-alert-soft text-alert-ink`), `vm-pill--neutral` (`bg-panel`, 1 px line
    border, `text-ink`);
  - `vm-table` (full width, collapsed; header 10.5–11 px uppercase `text-ink-muted`, `border-b border-line`; cells
    `py-2 px-2.5`, rows separated by `border-line-soft`; numeric cells use utility `text-right tabular-nums`);
  - `vm-row--highlight` (cells `bg-gold-wash`, first cell `box-shadow: inset 3px 0 0 var(--color-gold)`);
  - `vm-sub` (block, 11–12 px, `text-ink-muted`, small top margin);
  - `vm-medal` (18 px circle, 10 px bold, centred) + `vm-medal--1` (`bg-gold text-ink`), `--2` (`bg-silver`),
    `--3` (`bg-bronze`); rank 4+ is plain `text-ink-muted`;
  - `vm-label` (11–12 px uppercase, `tracking-wider`, semibold, `text-label`).
- Produces `ResultsHelper#game_result_pill(game) -> String (HTML)` — a `span.vm-pill` with
  `t("activerecord.attributes.game.results.#{game.result}")`: `peace_victory` → `--gold`, `mafia_victory` →
  `--alert`, `draw` and `in_progress` → `--neutral`.
- Produces `NewsHelper::NEWS_PHOTO_VARIANTS[:card] = { resize_to_fill: [ 160, 120 ], saver: { quality: 85 } }`.
- New i18n keys under `home.redesign` (ru / en): `running` «Идёт сейчас» / "Running now", `table_link` «таблица» /
  "table", `recently_finished` «Недавно завершились» / "Recently finished", `winner` «победитель» / "winner",
  `recent_games` «Последние игры» / "Recent games", `news` «Новости» / "News", `all_news` «все новости» / "all news".

- [ ] **Step 1: Failing helper specs** — `results_helper_spec.rb`: for each of the four results the pill has the
  right modifier class and label text; `news_helper_spec.rb`: `NEWS_PHOTO_VARIANTS[:card]` equals the hash above.

- [ ] **Step 2: Run** `bundle exec rspec spec/helpers/results_helper_spec.rb spec/helpers/news_helper_spec.rb` → FAIL.

- [ ] **Step 3: Implement** `ResultsHelper#game_result_pill`, the `:card` variant, and the CSS classes above. Run →
  PASS; `bin/rails tailwindcss:build` succeeds.

- [ ] **Step 4: Failing request spec** `spec/requests/redesign/home_spec.rb` (`include_context "with the new design"`,
  `get root_path`):
  - no intro (`home.hero.title` text absent), no what's new, Hall of Fame, stats or documents sections;
  - `#home-results` and `#home-news` present; on `lg` they are a two-column grid (class check), Results first;
  - Running now: one panel per running root competition with its name linking to `competition_path`, a "table" link,
    top 5 players in rank order with `vm-medal--1/2/3` on the first three and the rating; a running competition with
    no players → panel with no rows, no error (Review Focus 1);
  - Recently finished: up to 3, each with name link, end date, winner link; a finished competition with no games →
    row without winner (Review Focus 1);
  - Recent games: each with game link, series name, date, judge, `game_result_pill`;
  - News: 3 items, title links to the article, date, and the author's player name when `article.author.claimed_player?`;
    first variable photo as `img` from the `:card` variant; an
    article without photos or with only non-variable attachments → no `img` (Review Focus 2); a plain-text excerpt;
    "all news" links to `news_index_path`;
  - block toggles: `home_running_tournaments`, `home_recently_finished`, `home_recent_games`, `home_latest_news`
    disabled each removes its block; all three Results toggles disabled → no `#home-results`, `#home-news` spans the
    full width (class check); no news → no `#home-news`, Results full width;
  - `home_hero`, `home_hall_of_fame`, `home_stats` toggles have no effect on the new page;
  - default design: old page unchanged (one smoke example: `home.hero.title` present).

- [ ] **Step 5: Run** → FAIL.

- [ ] **Step 6: Implement.** `HomeController#index`: compute as today, but when `helpers.new_design?` skip
  `load_hall_of_fame_players` and `load_stats` and `render "home/redesign/index"`. Templates per the home spec's
  "Layout" section; `_event_slot` renders nothing (a comment marks it for #1198). Excerpt via
  `article.truncated_content(160).to_plain_text` (builder's call on length).

- [ ] **Step 7: Run** the new spec, `spec/requests/home_spec.rb`, `spec/requests/home_*` → PASS. Rubocop; evilution on
  `home_controller.rb` (`--spec spec/requests/redesign/home_spec.rb,spec/requests/home_spec.rb`),
  `results_helper.rb`, `news_helper.rb`.

- [ ] **Step 8: Commit** — `feat(redesign): add the redesigned home page`, `Closes #1171`.

---

### Task 2: Game page (vm-bpk.3 / #1172)

**Files:**
- Modify: `app/controllers/games_controller.rb`, `app/models/game.rb`, `app/helpers/games_helper.rb`,
  `config/locales/ru.yml`, `config/locales/en.yml`
- Create: `app/views/games/redesign/show.html.erb`, `_participation_row.html.erb`, `_neighbours.html.erb`; add
  `docs/superpowers/specs/2026-11-19-game-page-redesign-design.md`
- Test: `spec/models/game_spec.rb`, `spec/helpers/games_helper_spec.rb`, `spec/requests/redesign/game_spec.rb`

**Interfaces:**
- Consumes: `vm-pill*`, `vm-table`, `vm-row--highlight`, `vm-sub`, `vm-label`, `game_result_pill` (Task 1).
- Produces `Game#previous_in_competition -> Game | nil` and `Game#next_in_competition -> Game | nil` — neighbours in
  `competition.games` ordered by `played_on`, `game_number`, `table_number`, `id` (nulls last for `played_on`).
- Produces `GamesHelper#format_score(value) -> String` — `nil` → `""`; trims trailing zeros (`1.0` → `"1"`,
  `0.40` → `"0.4"`, `0.25` → `"0.25"`); negative values use U+2212: `-0.2` → `"−0.2"`.
- Produces `GamesHelper#score_parts(participation) -> String` for the phone fold: `"1 − 0.2 + ЛХ 0.4"`, omitting
  nil/zero minus and best move; plus always shown (`format_score(plus || 0)`); the «ЛХ» prefix from a new key.
- New i18n keys under `games.redesign` (ru / en): `first_shoot` «ПУ» / "FK", `best_move_seats` «ЛХ: %{seats}» /
  "BM: %{seats}", `best_move_short` «ЛХ» / "BM", `legend` «ПУ — первый убитый · ЛХ — лучший ход · Итого = Балл − Минус
  + ЛХ» / "FK — first killed · BM — best move · Total = Score − Minus + BM", `previous` «← Игра %{number}» /
  "← Game %{number}", `next` «Игра %{number} →» / "Game %{number} →", `competition_table` «таблица» / "table".
  Status text reuses `games.overlay.status.*`; the Минус header reuses `activerecord.attributes.game_participation.minus`.

- [ ] **Step 1: Failing model spec** — neighbours: first game → previous nil; last → next nil; middle → both; two
  games with the same `played_on` and `game_number` on tables 1 and 2 → ordered by table, neither returns itself
  (Review Focus 4); games of another competition never returned.

- [ ] **Step 2: Failing helper spec** — `format_score` table: `nil` → `""`, `0` → `"0"`, `1.0` → `"1"`, `0.40` →
  `"0.4"`, `0.25` → `"0.25"`, `-0.2` → `"−0.2"`, `-1` → `"−1"`; `score_parts`: plus only → `"1"`; plus + minus →
  `"0 − 0.2"`; plus + best move → `"1 + ЛХ 0.4"`; all three → `"1 − 0.5 + ЛХ 0.25"`.

- [ ] **Step 3: Run** → FAIL. **Implement** the two model methods and two helpers. Run → PASS.

- [ ] **Step 4: Failing request spec** `spec/requests/redesign/game_spec.rb` (`include_context "with the new design"`):
  - header: breadcrumbs (ancestors, competition, «Игра N»), `h1` «Игра N», `game_result_pill`, date via
    `format_date`, judge and table when present; with no date/judge/table → none of them and no empty separators
    (Review Focus 5); edit link only for a protocol manager;
  - finished game table: columns seat, player, Балл, Минус, ЛХ, Итого; values via `format_score`; Минус header text is
    the `minus` attribute label; a negative Минус cell has `text-alert-ink`; winners' rows have `vm-row--highlight`;
    role icons only when `roles_public?`;
  - secondary line: ПУ tag when `first_shoot`; status label for each non-alive status, none for alive; «ЛХ: 2, 5, 7»
    from `best_move_seats`; `best_move_seats` without `best_move` shows the seats only (Review Focus 3);
  - legend present on a finished game;
  - in-progress game: pill «Игра в процессе», only seat and player columns, no score cells, no legend, secondary line
    still shows status, ПУ and ЛХ seats;
  - neighbours: links to previous/next game paths with «Игра N» labels and a link to the competition; missing side
    empty;
  - default design: old page unchanged (smoke example: the «Доп. балл» header present).

- [ ] **Step 5: Run** → FAIL. **Implement** `GamesController#show` picking `games/redesign/show` when
  `helpers.new_design?`, and the templates per the game spec. Phone fold: score columns `hidden lg:table-cell`, the
  `score_parts` line `lg:hidden` inside `vm-sub`.

- [ ] **Step 6: Run** the new specs, `spec/requests/games_spec.rb`, `spec/requests/games_hidden_roles_spec.rb` →
  PASS. Rubocop; evilution on `game.rb` (`--target Game#previous_in_competition`, `Game#next_in_competition`),
  `games_helper.rb` (`--target GamesHelper#format_score`, `GamesHelper#score_parts`), `games_controller.rb`
  (`--spec spec/requests/redesign/game_spec.rb,spec/requests/games_spec.rb`).

- [ ] **Step 7: Commit** — `feat(redesign): add the redesigned game page`, `Closes #1172`.
