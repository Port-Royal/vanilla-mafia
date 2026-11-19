# Public site redesign — game page

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.3 / gh-1172
- Builds on: the foundation (`docs/superpowers/specs/2026-11-18-public-site-foundation-design.md`) and the home page
  design (`docs/superpowers/specs/2026-11-19-home-page-redesign-design.md`, which introduces the result pills)
- Status: design for approval

## Why

The game page (`/games/:slug`) is one of the most visited pages. Today it is a maroon table with seven columns, a green
background for winners, and a result line in grey text. It hides useful data the protocol already records (how a
player left the game, first killed, best-move picks), and one column is mislabelled: «Доп. балл» shows the `minus`
field, which is **subtracted** from the total (`GameParticipation#total = plus − minus + best_move`; the judge form
calls it «Минус»).

The owner skipped the questions and asked for the builder's proposal. The proposal below was shown as a mockup and
approved ("нормально").

## Goals

- Restyle the page in the warm paper look, behind `public_redesign`.
- Make the scoring readable: correct label for the penalty column, the total formula spelled out.
- Show the protocol data that is already stored but not displayed.
- Readable on a phone without sideways scrolling.
- Easy to move between games of the same series.

## Non-goals

- The OBS overlay (`/games/:slug/overlay`) — out of scope for the epic.
- Game breakdowns (judge-only).
- Changing what judges edit or how scores are computed.
- Changing the old game page.

## Constraints

- Behind `public_redesign`: when `new_design?` is false the page renders exactly as today.
- URLs stay. Existing i18n keys stay; new strings go into both `ru.yml` and `en.yml`.
- Existing specs keep passing; new specs cover the new design.
- Uses the foundation's opt-in classes. Shared components (builder's call, recorded here so the home page and this
  page agree): **whichever page task lands first builds them, the other reuses them; both branch from `master`.**
  Canonical class names, in `app/assets/tailwind/application.css`:
  - pill: `vm-pill` + `vm-pill--gold` (civilians win), `vm-pill--alert` (mafia win), `vm-pill--neutral` (draw, in
    progress);
  - table: `vm-table` (inside a `vm-panel`), `vm-row--highlight` (gold-wash row, gold left edge), `vm-sub` (the
    secondary line under a cell's main text);
  - rank medal: `vm-medal` + `vm-medal--1`, `--2`, `--3`;
  - section label: `vm-label`.
  The home page plan uses the same names.

## The page

Reference mockup (throwaway, local): `.artifacts.local/redesign-mockups/game-v1.html`.

### Header

- Breadcrumbs as today: ancestors of the competition, the competition, «Игра N». Gold-ish underlined links.
- Title: «Игра N» in the serif page-title style (the competition context is in the breadcrumbs, so the title is short;
  today's long `full_name` is no longer the title). Builder's call whether `name` (a game's optional custom name), when
  present, follows the number.
- Meta line: result pill, date (`played_on` through `format_date`, so the visitor's chosen date format applies —
  builder's call), «Судья: …» and «Стол: …» when present (existing keys).
- Result pill: the shared pill — civilians gold-soft, mafia alert-soft, draw neutral; while the game is in progress a
  neutral pill «Игра в процессе» (existing key `games.show.result.in_progress`) with a small gold dot.
- For users who `can_manage_protocols?`: «Редактировать протокол» link on the right of the title, as today.

### Table (finished game)

Columns: seat, player, Балл, Минус, ЛХ, Итого.

- **Player cell:** role icon (existing `roles/<code>.png`, only when roles are public — same rule as today:
  `@game.roles_public? && role_code.present?`), player name linking to the player. Below the name, a secondary line
  (ink-muted, small) with, in this order and only when present:
  - a small **ПУ** tag when `first_shoot`;
  - how the player left the game — the existing status labels (`killed_by_mafia` «Убит», `voted_out` «Повешен»,
    `banned` «ППК»; nothing for `alive`). Reuse the existing translations for the status enum; do not invent new
    wording;
  - «ЛХ: 2, 5, 7» from `best_move_seats` when present.
- **Балл** = `plus`, **Минус** = `minus`, **ЛХ** = `best_move`, **Итого** = `total` (bold). Numbers right-aligned,
  tabular, trailing zeros trimmed (`1`, `0.4`, `−0.25`, never `1.00` or `0.40`) — builder's call, one small formatting
  helper used everywhere on the page, including the phone fold. Empty cell instead of 0 for Минус and ЛХ when nil or zero (builder's call between empty and «—»; Балл and
  Итого always show a number).
- **Минус** is shown as a negative number in alert-ink («−0.20»). Its header uses the existing
  `activerecord.attributes.game_participation.minus` label («Минус» / its English counterpart) — the old page keeps its
  «Доп. балл» key untouched.
- **Winners** (`win`): the shared highlight row (gold-wash background, 3 px gold left edge) instead of today's green.
- Row order as today (by seat, nulls last, then id).
- Under the table, a one-line legend (new i18n key): «ПУ — первый убитый · ЛХ — лучший ход · Итого = Балл − Минус +
  ЛХ» (and English).

### Phone (below `lg`)

Columns: seat, player, Итого. The score parts fold into the player's secondary line, after the status/ПУ/ЛХ details:
«1 − 0.20 + ЛХ 0.40» (only the non-empty parts). The table never scrolls sideways.

### Game in progress

When `@game.in_progress?`:

- Result pill «Игра в процессе».
- Roles follow today's rule (`roles_public?`: hidden while in progress if `hide_roles` is on).
- **Proposed by the builder and approved:** scores (Балл, Минус, ЛХ, Итого) are not shown while the game is in
  progress — they aren't final. The table has only two columns, seat and player (no «Итого» column with dashes, unlike
  the mockup — builder's call), and the secondary line shows status, ПУ and «ЛХ: …» seats when recorded. The legend is
  hidden. This differs from today's page, which shows the in-progress numbers.

### Navigation between games

Below the table: «← Игра N−1», a link to the competition (its table), «Игра N+1 →».

- Neighbours are the previous and next games **in the same competition**, ordered by `played_on`, then
  `game_number`, then `id` (several tables can share a date and number — `game_number` is unique only per competition,
  date and table, so order by `table_number` too before `id`; builder settles the exact tie-break and pins it in a spec).
- Every game of the competition counts, in-progress games included (all games are public today).
- A missing neighbour leaves its side empty.
- Labels use the existing `common.game` key («Игра %{n}»-style; new key if a format with a number is needed).

## Testing

- Request specs with `include_context "with the new design"`: header (crumbs, title, meta, pill per result), table
  columns and values, Минус sign and label, secondary line (ПУ, each status, ЛХ seats), winners highlighted, roles
  hidden when not public, in-progress page without scores and legend, neighbour links (first, middle, last game; ties),
  the edit link only for protocol managers.
- `spec/requests/games_spec.rb` and `games_hidden_roles_spec.rb` keep passing against the old design.
- Mutation testing on any changed Ruby (neighbour lookup, helpers) per the project workflow.
- Manual check at 375, 768 and 1280 px.

## Left to the builder

- Whether a custom game `name` appears in the title.
- Empty vs «—» for zero/nil Минус and ЛХ.
- The exact neighbour tie-break (pinned in a spec).
- Where the neighbour lookup lives (model scope or a small query object).
