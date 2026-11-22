# Public site redesign — player profile

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.5 / gh-1174
- Builds on: the foundation spec and the home, game and competition page designs (all merged), and the shared
  components they built (`vm-panel`, `vm-table`, `vm-row--highlight`, `vm-sub`, `vm-pill*`, `vm-medal*`, `vm-label`,
  the news cards partial `shared/redesign/_news_cards`)
- Status: mockup approved by the owner ("looks good"); doc for approval

## Why

`/players/:slug` is where a player checks their own record and where others size a player up. Today it is a maroon
block with three numbers, grey role chips, award icons, then one collapsible six-column game table per season, oldest
game first. On a phone the tables scroll sideways. The page never says how the player did in each season, which is
the first thing people ask.

Found while studying the real page (dev data: 114 players, 53 with a photo, 1 with a bio, up to 142 games across 6
seasons, up to 11 awards):

- the current season (Сезон 6) has no `started_on` and sorts **last** (`Date.new(0)` fallback);
- the result column prints raw `win` / `lose`; dates print raw ISO, not through `format_date`;
- the result is shown even when the game's roles are hidden, which gives away the player's team;
- staff awards (Организатор, Главный судья, …) have no icon and render as bare text.

## Approaches

- **A. Restyle as is** — keep the per-season game log, new look. Cheapest; a 142-game player still gets a long list
  and no season summary.
- **B. Career summary first** — one row per season with place in that season's rating, games, wins and rating; each
  season opens to its games. Adds a rating lookup per season. **Chosen by the owner.**

## Goals

- Restyle the page in the warm paper look, behind `public_redesign`.
- Lead with a per-competition summary (seasons and other top-level competitions), including the player's place in
  each one's rating.
- Fix the findings above on the new page.
- Readable on a phone without sideways scrolling.

## Non-goals

- The old page (`new_design?` false renders exactly as today, bugs included), except where the builder fixes the
  season sort in the shared service (see "Left to the builder").
- Profile editing, claims and disputes flows themselves — only the link/button on this page.
- The hall of fame page and its `hall_of_fame/_award` partial.
- How ratings are computed.

## Constraints

- Behind `public_redesign`: the controller renders `players/redesign/show` when `helpers.new_design?`, like
  `GamesController#show`.
- URLs and existing i18n keys stay; new strings in both `ru.yml` and `en.yml` (under `players.redesign`).
- Reuse the shared components; no new rules on bare elements; no gold text (gold is non-text only).
- Existing specs (`spec/requests/players_spec.rb`, `player_claims_spec.rb`, `player_disputes_spec.rb`, acceptance
  specs touching the profile) keep passing against the old design.

## Reference

Mockup (throwaway, local): `.artifacts.local/redesign-mockups/player-v1.html` (Финчер's real numbers).

## The page

Sections in this order. A section with no data is not rendered (no empty headings).

### Header

- Photo: the attached photo (square, 8 px radius, line border; ~112 px desktop, ~72 px phone). Without a photo: the
  first letter of the name, serif, on a warm gradient tile of the same size (replaces `/img/nophoto.jpg` on the new
  page). `alt` = player name; the letter tile is `aria-hidden` (the name is right next to it).
- Name: `h1`, serif page title. Long names (e.g. «Девятый Игрок Фол (ДИФ)») wrap; no truncation.
- Meta line: «Играет с <date>» (existing `playing_since` key, date via `format_date`), only when there is a first game.
- Four big numbers: games (`total_games`), win % (`win_rate`), competitions (number of rows in «По турнирам»), awards (number of the
  player's award records, staff included — a repeat win counts each time, so «11 наград» may sit next to 8 badges whose
  sub lines list 11 competitions; builder's call). Labels are new pluralised keys («142 игры», «6 турниров», «11 наград»); a zero
  number is still shown except awards (hidden when 0).
- Action, right of the header on desktop, full-width button under the numbers on phones. Exactly today's conditions
  and targets, in today's order:
  - claimed by the viewer → «Редактировать профиль» (ghost button) → `edit_profile_path`;
  - admin → «Редактировать профиль» → Avo edit;
  - the viewer has a pending claim/dispute for this player → muted text «Заявка на рассмотрении» /
    «Запрос на оспаривание на рассмотрении»;
  - claimed by someone else and the viewer may dispute → «Оспорить профиль» (ghost) → `new_player_dispute_path`;
  - unclaimed and the viewer may claim → «Это я» (primary button, `button_to` with the existing turbo confirm);
  - signed out → nothing.

### Awards (label «Награды», existing key)

- Badges in a wrapping row: icon (32 px circle; the award's attached icon) + title + a `vm-sub` line listing the
  competitions it was won in.
- **Same award won several times → one badge**, competitions joined with «, » in the existing `position` order
  (e.g. «Почётный трупак — Сезон 3, Сезон 1»).
- **Staff awards** (`award.staff?`): the same badge, shown **first**, with a dark icon circle (ink background,
  gold-bright glyph) and **no** sub line. Owner's pick (option B of two shown). If a staff award has an attached icon,
  use it inside the dark circle.
- A non-staff award without an icon: the same dark-circle style is **not** used; show a gold-soft circle with the
  title's first letter (builder's call on the exact fallback).

### Roles (label «По ролям», existing key)

- One card per role from `stats.role_stats` (same order as today: most games first): role icon
  (`roles/<code>.png`), role name, «88 игр · 38.6%». Four columns desktop, two on phones (number of games without the
  word on phones is fine).
- Only roles from games with public roles count — unchanged service rule.

### Bio (label «О себе», existing key)

- Panel with the text, 16 px running-text size, line breaks kept (`whitespace-pre-line`), as today.

### Competitions (label «По турнирам» / "By competition", new key)

One row per root competition the player played in (today's `competitions_with_games` grouping by `root`), whatever
its kind — seasons, and also a top-level series, tournament, minicup or fun session (dev data already has a root
series). Owner's pick (option a): one list, no separate «seasons» wording. Below, «season» in column names means
«root competition»; the column header is «Турнир» (existing `players.show.competition` key).

- **Order:** running roots (`ended_on` nil) first, then by `started_on` descending; a root with no `started_on`
  counts as running/newest (fixes Сезон 6 sorting last). Ties by id descending.
- **Row:** root name (link to the competition) + «идёт» neutral pill when running; place; games; wins; rating
  (bold). Desktop columns: Турнир, Место, Игры, Победы, Рейтинг. Phone: Турнир, Место, Рейтинг, with «29 игр ·
  18 побед» (and «идёт» for a running season) in a `vm-sub` line under the name.
- **Place:** the player's position in the **same ranking the competition page shows for that root**, so the numbers
  agree (builder's call, settled after the builder check): a root with children → `Player.with_aggregated_stats
  .where(games: { competition_id: root.subtree_ids }).ranked` (as `CompetitionOverviewService#parent_result`); a root
  without children → the leaf ordering (sum of `total` desc, then player id, as `#leaf_result`). Ideally both come
  from one place in `CompetitionOverviewService` rather than being copied. Shown as the shared rank medal (1–3
  coloured, 4+ plain) followed by «из N» (N = players in that ranking). Games, wins and rating are the player's
  numbers in that root's subtree.
- **Expand/collapse:** native `<details>`/`<summary>`, no JS. The first row (newest) is open; the rest closed. The
  competition link inside the summary must still navigate (it does natively); the chevron is decorative.
- **Games of a season** (inside the open row), **newest first** (`played_on` desc, `game_number` desc, id desc):
  - Desktop columns: Дата (`format_date`), Игра («<series name> · Игра N», linking to the game; just «Игра N» when
    the game's competition is the root itself), Роль (icon + name, only when `game.roles_public?`), Итог, Балл
    (`total`, formatted with the game page's `format_score`, bold).
  - Итог: «Победа» gold pill / «Поражение» plain pill / «Ничья» neutral pill; **blank when roles are not public**
    (fixes the leak) and blank while the game is in progress (`result` is nil). Балл is blank while in progress.
  - Won games: `vm-row--highlight` when `result == "win"` — not the stored `win` flag — so a game whose result is
    blank (hidden roles, in progress) is never highlighted (builder's call).
  - Phone: two columns — role icon + game link with a `vm-sub` line «21 февраля · победа», and Балл.
- **Empty:** a player with no games shows «Игр пока нет» (new key) in place of the seasons panel, and no numbers row
  beyond games = 0 / win % = 0.

### News (label «Новости», existing key)

- The articles mentioning the player, through the shared `shared/redesign/_news_cards` partial. Omitted when none.

## Data

`PlayerProfileService` grows a per-season summary for the new page. The old page keeps using its current fields
unchanged.

- New value object per season: competition (root), games (that root's games for the player, newest first), place,
  ranked_count, games_count, wins_count, rating, running?.
- Place lookup: one `with_stats_for_competition(root).ranked` query per root (≤ ~10 roots per player today); builder
  may batch it if simple. Avoid N+1 on games' competitions and participations (`includes`).
- Award grouping: group `player_awards` by `award_id`, staff first, then by the existing `position` order of the
  first occurrence.

## Testing

- Request spec `spec/requests/redesign/player_spec.rb` with `include_context "with the new design"`: header (photo vs
  letter tile, name, since-date, numbers and plurals), each action-button state, awards grouping and staff-first
  style, role cards, bio, season rows (order incl. a root without `started_on`, place and «из N», medal for 1–3,
  running pill), games inside a season (order, link text with/without series, result pills, blank result when roles
  hidden or in progress, highlight for wins), empty player, news present/absent.
- Service spec for the new season summary (place matches the competition page ranking, ordering, ties).
- Old specs keep passing.
- Evilution on changed Ruby (service, helpers, controller), per project workflow.
- Manual check at 375, 768, 1280 px.

## Left to the builder

- Whether the season sort fix also goes into the old page (it is a shared service; fixing it there too is acceptable
  and simpler — call it out in the PR).
- Fallback look for a non-staff award without an icon.
- Batching the place queries.
- Exact sizes within the foundation type scale.
