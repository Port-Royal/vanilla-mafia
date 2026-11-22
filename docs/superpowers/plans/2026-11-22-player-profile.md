# Player Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigned `/players/:slug` shown when `new_design?`; the old page is unchanged otherwise.

**Architecture:** A small `CompetitionRanking` service becomes the single source of a competition's standings (used
by `CompetitionOverviewService` for the leaf order and by the profile for «Место»). `PlayerProfileService` gains
two result fields, `competition_summaries` and `award_badges`; the old view ignores them. `PlayersController#show`
renders `players/redesign/show` when `helpers.new_design?`, split into small partials.

**Tech Stack:** Rails 8.1, Tailwind v4, RSpec (request/service/helper specs, `let_it_be`), evilution.

**Spec:** `docs/superpowers/specs/2026-11-21-player-profile-redesign-design.md` (ships with this PR).

## Global Constraints

- Old page unchanged: `spec/requests/players_spec.rb`, `player_claims_spec.rb`, `player_disputes_spec.rb`,
  `spec/acceptance/player_profile_spec.rb`, and the competition specs (`spec/requests/competitions_spec.rb`,
  `spec/requests/redesign/competition_spec.rb`, `spec/acceptance/season_overview_spec.rb`, `series_totals_spec.rb`)
  pass untouched.
- New-design specs use `include_context "with the new design"`.
- Reuse `vm-panel`, `vm-table`, `vm-row--highlight`, `vm-sub`, `vm-pill`, `vm-pill--gold`, `vm-pill--neutral`,
  `vm-medal vm-medal--N` (1–3; 4+ gets `text-ink-muted`, as in `competitions/redesign/_parent`), `vm-label`,
  `vm-btn vm-btn--primary|--ghost`, `format_score`, `format_date`, `shared/redesign/_news_cards`. No new rules on bare
  elements; no gold text.
- New strings in both locales under `players.redesign`; Russian counts use `one`/`few`/`many`/`other`. Existing
  `players.show.*` keys reused where the spec says so.
- No `&.`, no `and return`; specs: `let_it_be`/`let`, nested contexts, no variables inside `it`.
- Git writes (commit/push/PR) only with the owner's permission — ask at each commit step.

## Review Focus

1. Player with a single game in a root competition without children (the dev root series) — row shows place «из N»
   matching that competition page's order. → Task 1 (ranking) and Task 2 (summary).
2. Player with no games at all (one exists in dev data) — no seasons panel, «Игр пока нет», no «Играет с», no crash. →
   Task 4.
3. Game with hidden roles (`hide_roles` + in progress) — role, result and highlight all blank, even if `win` is true in
   the DB. → Task 4.
4. Player with no photo, no awards, no bio, no news — letter tile; those sections absent, no empty headings. → Task 3.
5. Plural boundaries for the big numbers and phone sub lines (1, 2, 5, 11, 21). → Task 3.

---

### Task 1: `CompetitionRanking`

**Files:**
- Create: `app/services/competition_ranking.rb`
- Modify: `app/services/competition_overview_service.rb` (`leaf_result` sort)
- Test: `spec/services/competition_ranking_spec.rb`

**Interfaces:**
- Produces: `CompetitionRanking.call(competition) -> Array<CompetitionRanking::Entry>`, ordered best first.
  `Entry = Data.define(:player_id, :games, :wins, :rating)` (`rating` BigDecimal).
  - `competition.children.exists?` → rows of `Player.with_aggregated_stats.where(games: { competition_id:
    competition.subtree_ids }).ranked` (`games_count`, `wins_count`, `total_rating`) — identical to
    `CompetitionOverviewService#parent_result`'s `players`.
  - otherwise → participations of `Game.where(competition:)`, grouped by `player_id`; rating = sum of `total`, games =
    count, wins = count of `win`; ordered by `CompetitionRanking.leaf_sort_key(player_id, rating)` = `[-rating,
    player_id]`.
- `CompetitionOverviewService#leaf_result` sorts `players_sorted` with `CompetitionRanking.leaf_sort_key(p.id, sum)` so
  both orders come from one place (behaviour unchanged).

- [ ] **Step 1: Write failing specs** — contexts: "with children" (entries equal `with_aggregated_stats…ranked` order,
  including a tie broken by wins then games then name; games from a grandchild count); "without children" (two players
  tied on total → lower id first; games/wins/rating values); "with no games" → `[]`.
- [ ] **Step 2: Run** `bundle exec rspec spec/services/competition_ranking_spec.rb` — FAIL (uninitialized constant).
- [ ] **Step 3: Implement** `CompetitionRanking` and switch `leaf_result` to `leaf_sort_key`.
- [ ] **Step 4: Run** the new spec plus `spec/services/competition_overview_service_spec.rb`,
  `spec/requests/competitions_spec.rb`, `spec/requests/redesign/competition_spec.rb` — all PASS.
- [ ] **Step 5: Commit** (ask first) — `feat: extract competition ranking`.

### Task 2: Profile data — competition summaries and award badges

**Files:**
- Modify: `app/services/player_profile_service.rb`
- Test: `spec/services/player_profile_service_spec.rb`

**Interfaces:**
- Consumes: `CompetitionRanking.call`.
- Produces on `PlayerProfileService::Result`:
  - `competition_summaries: Array<CompetitionSummary>`,
    `CompetitionSummary = Data.define(:competition, :games, :place, :ranked_count, :games_count, :wins_count, :rating,
    :running)`. One per root of the player's games. `games` = that root's games for the player, newest first
    (`played_on` desc, `game_number` desc, `id` desc), with `competition` and `game_participations` preloaded.
    `place` = 1-based index of the player's entry in `CompetitionRanking.call(root)`; `ranked_count` = entries size;
    `games_count`/`wins_count`/`rating` from that entry. `running` = `root.ended_on.nil?`.
    Order: running first, then `started_on` desc with nil treated as newest, then `id` desc.
  - `award_badges: Array<AwardBadge>`, `AwardBadge = Data.define(:award, :competitions)`. `player_awards` grouped by
    `award`; `competitions` = non-nil competitions in `position` order; staff awards first, then by the position of
    each award's first occurrence. Preload `:award, :competition` (and the award icon attachment).
- Existing fields (`competitions_with_games`, `player_awards`, `stats`, …) unchanged; `news_articles` additionally
  preloads `photos_attachments: :blob` (needed by the news cards).

- [ ] **Step 1: Write failing specs** under `describe "#competition_summaries"`: order (finished older, finished newer,
  running, root without `started_on` → running/no-date roots first, newest finished next); place and «из N» values
  matching `CompetitionRanking`; root without children uses leaf order; games newest first incl. a same-date pair by
  `game_number`. Under `describe "#award_badges"`: same award twice → one badge, two competitions in position order;
  staff award first with no competitions; award with nil competition.
- [ ] **Step 2: Run** `bundle exec rspec spec/services/player_profile_service_spec.rb` — new examples FAIL.
- [ ] **Step 3: Implement** the two fields as private builders (`build_competition_summaries`, `build_award_badges`).
- [ ] **Step 4: Run** the service spec and `spec/requests/players_spec.rb` — PASS.
- [ ] **Step 5: Commit** (ask first) — `feat: player profile competition summaries and award badges`.

### Task 3: Redesigned page — header, action, awards, roles, bio, news

**Files:**
- Modify: `app/controllers/players_controller.rb` (assign the two new fields; `render "players/redesign/show" if
  helpers.new_design?`), `config/locales/ru.yml`, `config/locales/en.yml`
- Create: `app/views/players/redesign/show.html.erb`, `_header.html.erb`, `_action.html.erb`, `_awards.html.erb`,
  `_roles.html.erb`; `app/helpers/players_helper.rb` (or additions if it exists)
- Test: `spec/requests/redesign/player_spec.rb`, `spec/helpers/players_helper_spec.rb`

**Interfaces:**
- Controller ivars: `@competition_summaries`, `@award_badges` in addition to today's.
- `PlayersHelper#player_initial(player) -> String` — first character of the stripped name, upcased.
- `_action` keeps today's branch order and conditions verbatim from `players/show.html.erb` (claimed by viewer →
  edit; admin → Avo edit; pending claim/dispute text; dispute; claim with `turbo_confirm`), existing `players.show.*`
  keys; primary button for «Это я», ghost for the others.
- i18n `players.redesign` (ru / en): `competitions` «По турнирам» / "By competition"; `numbers.games` count forms of
  the bare word («игра / игры / игр» / "game / games"), `numbers.wins_pct` «побед» / "wins",
  `numbers.competitions` («турнир / турнира / турниров» / "competition / competitions"), `numbers.awards`
  («награда / награды / наград» / "award / awards").
- Big numbers: games, win % (`stats.win_rate` + «%»), competitions (`@competition_summaries.size`), awards
  (`@player_awards.size`, hidden when 0). Photo `variant(resize_to_limit: [224, 224])`; no photo → letter tile
  `aria-hidden="true"` with `player_initial`.
- Awards: staff badge dark circle (`bg-ink`, glyph/icon in `text-gold-bright`), no sub line; others gold-soft circle
  with icon (or `player_initial(award.title)`-style first letter), sub line = competition names joined «, ».
- Roles: cards for `stats.role_stats` with `roles/<code>.png`, «%{count} игр · N%» (count forms).
- Bio panel and news (`shared/redesign/_news_cards`, `heading: t("players.show.news")`, `all_link: nil`) only when
  present.

- [ ] **Step 1: Write failing request specs** (contexts per section): photo vs letter tile; name; «Играет с» present /
  absent; numbers and plurals at 1, 2, 5, 11, 21; each action state (signed out → none; owner; admin; pending claim;
  pending dispute; can dispute; can claim); awards grouped, staff first without sub line; roles cards; bio
  present/absent; news present/absent; no empty section labels for a bare player. Helper spec for `player_initial`
  (Latin, Cyrillic, leading space).
- [ ] **Step 2: Run** `bundle exec rspec spec/requests/redesign/player_spec.rb spec/helpers/players_helper_spec.rb` —
  FAIL.
- [ ] **Step 3: Implement** controller switch, partials, helper, i18n.
- [ ] **Step 4: Run** the new specs and all old player specs (Global Constraints list) — PASS; `bin/rails
  tailwindcss:build` OK.
- [ ] **Step 5: Commit** (ask first) — `feat: redesigned player profile header, awards and roles`.

### Task 4: Redesigned page — «По турнирам» section

**Files:**
- Create: `app/views/players/redesign/_competitions.html.erb`, `_competition_games.html.erb`
- Modify: `app/helpers/players_helper.rb`, both locale files
- Test: `spec/requests/redesign/player_spec.rb`, `spec/helpers/players_helper_spec.rb`

**Interfaces:**
- Consumes: `CompetitionSummary` (Task 2), `format_score`, `format_date`.
- `PlayersHelper#profile_result_pill(participation) -> String | nil` — nil unless `participation.game.roles_public?`
  and `participation.result` present; `"win"` → `vm-pill vm-pill--gold` «Победа»; `"lose"` → `vm-pill` «Поражение»;
  `"draw"` → `vm-pill vm-pill--neutral` «Ничья».
- `PlayersHelper#profile_game_label(game, root) -> String` — `game.competition == root` → «Игра N», else
  «<competition name> · Игра N».
- Highlight row (`vm-row--highlight`) iff `roles_public?` and `result == "win"`.
- i18n `players.redesign`: `place_of` «из %{count}» / "of %{count}"; `running` «идёт» / "running"; `no_games`
  «Игр пока нет» / "No games yet"; `game` «Игра %{number}» / "Game %{number}"; `game_in` «%{competition} · Игра
  %{number}» / "%{competition} · Game %{number}"; `result.win|lose|draw` «Победа / Поражение / Ничья» / "Win / Loss /
  Draw"; `summary_sub.games` count forms («%{count} игра…»), `summary_sub.wins` («%{count} победа / победы / побед»);
  column headers `place` «Место», `games` «Игры», `wins` «Победы», `rating` «Рейтинг», `date` «Дата» (en equivalents);
  `Турнир` header reuses `players.show.competition`.
- Markup: one `vm-panel` with a header row and one `<details>` per summary; the first has `open`. Summary row: name
  link + `vm-pill vm-pill--neutral` «идёт» when running; medal + «из N»; games and wins `hidden lg:…`; rating bold via
  `format_score`. Phone `vm-sub` under the name: «идёт · » when running + games + wins. Games table: Дата, Игра, Роль,
  Итог, Балл on desktop; phone shows role icon + label with `vm-sub` «<date> · <result word lowercased>» and Балл.
  Балл blank while the game is in progress.

- [ ] **Step 1: Write failing specs**: rows in summary order with place, «из N», medal classes for 1, 3 and 4;
  running pill; first `details` open only; game rows newest first; label with and without series; result pill per
  result; hidden roles (`hide_roles` toggle + in-progress game with `win: true`) → no role, no pill, no highlight;
  finished draw → neutral pill; in-progress Балл blank; won row highlighted; player without games → «Игр пока нет» and
  no panel. Helper specs for both helpers (each branch).
- [ ] **Step 2: Run** the request and helper specs — new examples FAIL.
- [ ] **Step 3: Implement** partials, helpers, i18n.
- [ ] **Step 4: Run** new specs, old specs (Global Constraints), `bundle exec rubocop` on changed Ruby — PASS / no
  offences.
- [ ] **Step 5: Commit** (ask first) — `feat: redesigned player profile competitions section`; include the spec and
  this plan.

### Task 5: Verification

- [ ] **Step 1:** Full suite without system specs: `bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"` —
  0 failures; `npm test` passes.
- [ ] **Step 2:** Evilution, `NO_COVERAGE=1 bundle exec evilution run <file> --jobs 1 --spec <specs>` on
  `app/services/competition_ranking.rb`, `app/services/player_profile_service.rb`
  (`--spec spec/services/player_profile_service_spec.rb,spec/requests/redesign/player_spec.rb`),
  `app/helpers/players_helper.rb` (`--spec spec/helpers/players_helper_spec.rb`), `app/controllers/players_controller.rb`
  (`--spec spec/requests/players_spec.rb,spec/requests/redesign/player_spec.rb`),
  `app/services/competition_overview_service.rb` (changed lines). Kill survivors or record why equivalent.
- [ ] **Step 3:** Append the run to `.artifacts.local/regular-evilution-feedback.log` (local only).
- [ ] **Step 4:** Manual look at 375 / 768 / 1280 px in dev (`fincher`, a player with no games, a player without photo).
- [ ] **Step 5:** `bd close vm-bpk.5` and PR only when the owner says so (PR body: `Closes #1174`, bead, decisions
  incl. the season-sort fix not applied to the old page, verification; no mutation results posted to GitHub).
