# Public site redesign — competition pages

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.4 / gh-1173
- Builds on: the foundation spec, the home page and game page designs (all merged), and the shared components they
  built (`vm-pill*`, `vm-table`, `vm-row--highlight`, `vm-sub`, `vm-medal*`, `vm-label`, tokens `gold-ink`,
  `gold-line`)
- Status: approved by the owner ("looks good") after a mockup; the owner skipped the questions and asked for the
  builder's proposal

## Why

`/competitions/:slug` has two views today (`CompetitionOverviewService`):

- **Parent view** — a competition with children (a season, a tournament with rounds): a table of child competitions
  with their game numbers, then the player standings, then news.
- **Leaf view** — a competition without children (a series, a minicup): a player × game matrix of totals, sorted by
  total, then news.

Both are maroon `.data-table`s with no rank numbers, no status, and the standings — what players come for — below the
list of series.

## Goals

- Restyle both views in the warm paper look, behind `public_redesign`.
- Standings first.
- Add what's missing: rank numbers with medals, the running/finished status, counts, the winner of each finished child,
  which games a player won.
- Readable on a phone.

## Non-goals

- Changing how ratings, totals or ordering are computed.
- Changing which games count for a parent (today: games whose competition is the child itself; games of
  grandchildren are not listed under a child — keep that).
- The old pages.

## Constraints

- Behind `public_redesign`: `new_design?` false → old pages exactly as today.
- URLs and existing i18n keys stay; new strings in both `ru.yml` and `en.yml`.
- Reuse the shared components; no new rules on bare elements; no gold text.
- Existing specs (`spec/requests/competitions_spec.rb`, acceptance `season_overview_spec.rb`,
  `series_totals_spec.rb`) keep passing against the old design.

## Reference

Mockup (throwaway, local): `.artifacts.local/redesign-mockups/competition-v1.html`.

## Header (both views)

- Breadcrumbs from the competition's ancestors (none for a root), gold-line underlines.
- Title: the competition name, serif page title.
- Meta line:
  - a **«Идёт» pill** (`vm-pill--neutral` with a gold dot) when `ended_on` is nil; no pill when finished (avoids
    gendered «Завершён/Завершена»);
  - dates: running → «с <started_on>»; finished → «<started_on> – <ended_on>»; missing dates are omitted; dates via
    `format_date`;
  - counts: parent view — «N серий · N игр · N игроков» for a season, «N этапов · …» for other parents (children,
    games in the subtree, players in the standings);
    leaf view — «N игр · N игроков». Pluralised Russian via i18n `count` keys (one/few/many/other).

## Parent view

Sections in this order, each with a `vm-label` heading:

1. **Rating** — the existing `players` (subtree standings, `ranked`). Columns: rank (medal 1–3, plain number after),
   player (link), rating (bold), games, win % (existing `win_percentage`). On phones: rank, player, rating; games and
   win % fold into a `vm-sub` line under the name («22 игры · 63.6%»).
2. **Children** — label depends on the parent's kind (decided by the owner): a **season** says «Серии» / "Series";
   every other parent kind (tournament, …) says «Этапы» / "Stages". Same rule for the count in the header
   («4 серии» vs «3 этапа»). New keys for both words, with plural `count` forms. One row per child (existing `games_by_child`
   order): child name linking to it; a `vm-sub` line with its dates (or «идёт» when running) and, when the child is
   finished, «победитель <player link>» — the top of that child's standings (`Player.with_stats_for_competition(child)
   .ranked.first`, same as the home page's winners); then its games as small chips (game number linking to the game;
   an in-progress game's chip has a gold border). On phones the chips wrap under the name.
3. **News** — the competition's news (existing `news`), rendered like the home page news cards (thumbnail, title as
   `h3`, date, author, excerpt). Omitted when there is none. Reuse the home page partial if it fits (extract it to a
   shared partial if needed — builder's call).

## Leaf view

1. **Matrix** in a horizontally scrollable `vm-panel`:
   - First column (sticky on horizontal scroll): rank medal + player name (link). Rank = position in the existing
     `players_sorted` order (total desc, then player id).
   - One column per game (existing `games` order): header «И<game_number>» linking to the game. Cell: that player's
     total in that game, formatted with `format_score` (trailing zeros trimmed, U+2212 minus); empty when the player
     didn't play. A cell where the player **won** that game (`participation.win`) gets the gold-wash background (cell-
     level, not the whole row). Negative totals in alert-ink.
   - **Итого** column (bold). On `lg+` it is the last column; below `lg` it is shown right after the player column
     instead (so standings are visible without scrolling).
   - A one-line legend under the table: «Золотистая ячейка — победа в этой игре. Пустая — не играл.» (new key, en
     too).
2. **News** — as in the parent view.

## Empty states

- Parent with no players yet → no Rating section; children still listed.
- Leaf with no games → the matrix is replaced by a short «Игр пока нет» / "No games yet" line.
- No news → no News section.

## Testing

- Request specs with `include_context "with the new design"` for both views: header (crumbs, title, pill only when
  running, dates, counts with correct plural forms), parent sections order, medals, phone fold line, child rows with
  dates/winner/chips (in-progress chip marked), leaf matrix (rank, game headers and links, cell values via
  `format_score`, empty cells, won-cell highlight, negative styling, Итого in both positions), legend, empty states,
  news cards.
- Existing competitions specs keep passing against the old design.
- Mutation testing on changed Ruby (controller/service additions, any helper).
- Manual check at 375, 768 and 1280 px.

## Left to the builder

- Where the per-child winner lookup lives (service result field vs. helper) — avoid N+1 beyond one query per child.
- Whether the home news partial is reused directly or extracted to a shared partial.
- Exact chip and table spacing within the foundation scale.
