# Public site redesign — stats page

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: gh-1199
- Builds on: the foundation spec, the home page design (its "Follow-up tasks" asked for this page) and the shared
  components (`vm-panel`, `vm-table`, `vm-sub`, `vm-pill`, `vm-label`, tokens `gold-soft`, `alert-soft`, `ink-muted`, …)
- Status: decided by the builder in an autonomous run (no mockup round with the owner)

## Why

The old home page ends with a «Клуб в цифрах» block: three numbers — players (`Player.count`), games played
(`Game.finished.count`) and competitions (`Competition.roots.finished.count`). The redesigned home page drops it. The
owner wants it as its own page, reachable from the menu.

Dev data: 114 players, ~220 finished games since 13.01.2024, six seasons (one running) and one empty root competition.

## What the page shows

Kept small: the three numbers plus two things computed from the same tables, both cheap and both answering what a
visitor of a mafia club asks next ("who wins more often?", "how big was each season?").

1. **Title** «Клуб в цифрах» (existing `home.stats.title`), serif, and a muted line «Играем с <date>» — the date of the
   first finished game (`Game.finished.minimum(:played_on)`), omitted when there is none.
2. **Three numbers** — players, games, competitions — in one `vm-panel`, three columns on every width, big tabular
   numbers in ink, labels under them (existing `home.stats.players` / `games` / `competitions`). Same definitions as
   the old block.
3. **Who wins** (`vm-label` heading) — finished games by result: «Победы мирных», «Победы мафии», and «Ничьи» only when
   there are any. Each shows the count and its share of finished games (rounded percent). A thin stacked bar on top
   (gold-soft for the town, alert-soft for the mafia, line for draws; decorative, `aria-hidden`), the same colours as
   the result pills on the game pages. Omitted when no game has finished.
4. **By competition** (`vm-label` heading) — a `vm-table`, one row per root competition with at least one finished
   game, newest first (`roots.ordered` reversed, so the admin's order is kept). Columns: name (link to the competition,
   a «идёт» pill when it is running), games, players (distinct players in its finished games), town wins, mafia wins.
   On phones the two win columns fold into a `vm-sub` line under the name. A subtree's games count for its root.
   Empty → «Игр пока нет.», muted.

Left out (owner may want them later): leaderboards (most games, best win rate) — they overlap the competition and hall
pages and need ranking rules; per-role win rates; charts over time.

## Queries

`ClubStatsService.call` — a fixed number of queries whatever the data size, no N+1:

- the three totals (`ClubStatsService.totals`, also used by the old home block instead of its own copy);
- first game date;
- finished games grouped by competition and result (one `GROUP BY`) — gives the result split and the per-root counts;
- all competitions' `id, parent_id` (a small table) to map a competition to its root in Ruby;
- distinct `(competition_id, player_id)` pairs of finished games' participations, for players per root;
- the root competitions themselves.

## Toggle and URL

- New route `GET /stats` (`stats_path`) → `StatsController#show`, rendering `stats/redesign/show`.
- The page exists only in the new design. With `new_design?` false it answers **404** (`ActionController::RoutingError`,
  the app's normal not-found page) — the old design still has the block on its home page. The check is one
  `before_action` in `StatsController`; the cleanup task (vm-bpk.10) deletes it.
- Menu: «Статистика» / «Stats» (`nav.stats`) after News in the top bar, the phone menu and the footer links. The
  narrow active-item rule applies unchanged (`current_page?`).
- The `home_stats` block toggle does not affect the page: it is a home-block toggle, and the new home page already
  ignores it.

## Testing

- `spec/services/club_stats_service_spec.rb`: totals, result split (unknown results ignored), first game date,
  per-root rows (subtree games, distinct players, unfinished games and empty roots left out, order), empty data.
- `spec/requests/redesign/stats_spec.rb`: 404 with the old design and when the visitor declined the offer; the page with
  the new design (numbers, first-game line, result split and percentages, draws only when present, table rows, links,
  running pill, phone fold, empty states); query count stays flat as data grows.
- Shell, phone menu and footer specs: the new link in order and its active state.
- `spec/requests/home_spec.rb` keeps passing against the old home block.
