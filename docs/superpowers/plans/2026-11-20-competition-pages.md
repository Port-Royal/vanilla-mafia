# Competition Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigned `/competitions/:slug` (parent and leaf views) shown when `new_design?`; old pages unchanged otherwise.

**Architecture:** `CompetitionsController#show` keeps using `CompetitionOverviewService`, which gains one result field
(`child_winners`); the controller renders `competitions/redesign/show` when `helpers.new_design?`. The home page's news
card list is extracted to a shared partial and reused. Ranking, totals and ordering are unchanged.

**Tech Stack:** Rails 8.1, Tailwind v4, RSpec (request/service/helper specs, `let_it_be`), evilution.

**Spec:** `docs/superpowers/specs/2026-11-20-competition-pages-redesign-design.md` (ships with this PR).

## Global Constraints

- Old pages unchanged: `spec/requests/competitions_spec.rb`, `spec/acceptance/season_overview_spec.rb`,
  `series_totals_spec.rb` pass untouched; the home page specs pass after the news-partial extraction.
- New-design specs use `include_context "with the new design"`.
- Reuse `vm-pill*`, `vm-table`, `vm-sub`, `vm-medal*`, `vm-label`, tokens `gold-line`, `gold-wash`, `alert-ink`;
  `format_score` for numbers; no new rules on bare elements; no gold text.
- New strings in both locales; Russian counts use plural `count` forms (`one`/`few`/`many`/`other`).
- No `&.`, no `and return`; specs: `let_it_be`/`let`, nested contexts, no variables inside `it`.

## Review Focus

1. A running child with no games and no players — row shows «идёт», no winner, no chips, no error. → Task 1.
2. A finished child whose games have no participations — no winner, no error. → Task 1.
3. A leaf competition with games but a player who played only some of them — empty cells, total from played games. →
   Task 1.
4. Counts at plural boundaries (1, 2, 5, 11, 21) render the right Russian form. → Task 1.
5. A parent that is not a season (e.g. tournament) never shows «Серии» / «серий». → Task 1.

---

### Task 1: Competition pages (vm-bpk.4 / #1173)

**Files:**
- Modify: `app/controllers/competitions_controller.rb`, `app/services/competition_overview_service.rb`,
  `app/views/home/redesign/_news.html.erb` (becomes a thin wrapper), `config/locales/ru.yml`, `config/locales/en.yml`
- Create: `app/views/shared/redesign/_news_cards.html.erb`, `app/views/competitions/redesign/show.html.erb`,
  `_header.html.erb`, `_parent.html.erb`, `_leaf.html.erb`; `app/helpers/competitions_helper.rb` additions
- Test: `spec/services/competition_overview_service_spec.rb`, `spec/helpers/competitions_helper_spec.rb`,
  `spec/requests/redesign/competition_spec.rb`; add the spec document

**Interfaces:**
- `CompetitionOverviewService::Result` gains `child_winners: Hash{Competition => Player | nil}` — for each child with
  `ended_on` present, `Player.with_stats_for_competition(child).ranked.first`; running children map to `nil`. Leaf
  results return `{}`.
- `CompetitionsHelper#children_label(competition, count: nil) -> String` — `competition.season?` → key
  `competitions.redesign.children.series`, otherwise `competitions.redesign.children.stages`; with `count:` returns
  the pluralised count phrase («4 серии», «3 этапа»), without it the section label («Серии», «Этапы»).
- `CompetitionsHelper#competition_dates(competition) -> String` — running: «с <format_date(started_on)>» (empty if no
  `started_on`); finished: «<start> – <end>» (either side omitted when nil, no dangling dash).
- `shared/redesign/_news_cards` locals: `articles:` (preloaded relation), `heading:` (string), `all_link:` (path or
  nil). Home passes `t("home.redesign.news")` and `news_index_path`; competition pages pass a new
  `competitions.redesign.news` label and `nil`.
- New i18n keys under `competitions.redesign` (ru / en): `running` «Идёт» / "Running"; `since` «с %{date}» /
  "since %{date}"; `rating` «Рейтинг» / "Rating"; `children.series` «Серии» / "Series" and its `count` forms («%{count}
  серия / серии / серий»); `children.stages` «Этапы» / "Stages" with count forms («этап / этапа / этапов»);
  `games_count` and `players_count` count forms («игра/игры/игр», «игрок/игрока/игроков»); `winner` «победитель» /
  "winner"; `running_short` «идёт» / "running"; `news` «Новости» / "News"; `no_games` «Игр пока нет» / "No games
  yet"; `legend` «Золотистая ячейка — победа в этой игре. Пустая — не играл.» / "Gold cell — won that game. Empty — did
  not play."; `game_short` «И%{number}» / "G%{number}"; `total` reuses `competitions.show.total`.

- [ ] **Step 1: Failing service spec** — parent: `child_winners` maps a finished child to its top-ranked player, a
  running child to nil, a finished child without participations to nil (Review Focus 2); leaf: `{}`.

- [ ] **Step 2: Failing helper spec** — `children_label` for a season and a tournament, with and without `count`,
  counts 1, 2, 5, 11, 21 in ru (Review Focus 4, 5); `competition_dates` for running/finished with each date missing.

- [ ] **Step 3: Run** both → FAIL. **Implement** the service field and helpers. Run → PASS.

- [ ] **Step 4: Extract** the home news list to `shared/redesign/_news_cards` with the locals above; `home/redesign/_news`
  renders it. Run `spec/requests/redesign/home_spec.rb` → still PASS (no visible change).

- [ ] **Step 5: Failing request spec** `spec/requests/redesign/competition_spec.rb` (`include_context "with the new
  design"`):
  - header: crumbs for a child, serif `h1` with the name, «Идёт» pill only when `ended_on` is nil, dates via
    `competition_dates`, counts («4 серии · 24 игры · 31 игрок» on a season; «этап…» on a tournament; leaf: games and
    players only);
  - parent: sections in order Rating → children → News; rating rows with `vm-medal--1/2/3`, rating, games, win %, a
    `vm-sub lg:hidden` fold line with games and win %; children rows with name link, dates or «идёт», winner link when
    finished, game chips linking to games, an in-progress game chip marked (class check); a running child with no games
    (Review Focus 1); a tournament parent's label is «Этапы» and no «Серии» text appears (Review Focus 5);
  - leaf: sticky player column with rank medals in `players_sorted` order; one header «И<n>» per game linking to it;
    cells via `format_score`; empty cell for a game the player skipped and the total from played games only (Review
    Focus 3); won cells have `bg-gold-wash`; negative cells `text-alert-ink`; «Итого» rendered twice (`lg:hidden` after
    the player, `hidden lg:table-cell` last); legend present; no games → `no_games` line instead of the table;
  - news cards when the competition has news, no section otherwise;
  - default design: old page unchanged (smoke: the old maroon `data-table` present).

- [ ] **Step 6: Run** → FAIL. **Implement** `CompetitionsController#show` (`render "competitions/redesign/show" if
  helpers.new_design?` after loading) and the templates per the spec.

- [ ] **Step 7: Run** the new specs, the old competitions/acceptance specs and the home specs → PASS. Rubocop; evilution
  on `competition_overview_service.rb`, `competitions_helper.rb` (methods above), `competitions_controller.rb`
  (`--spec spec/requests/redesign/competition_spec.rb,spec/requests/competitions_spec.rb`). Full suite without system
  specs; `npm test`.

- [ ] **Step 8: Commit** — `feat(redesign): add the redesigned competition pages`, `Closes #1173`.
