# Public site redesign — hall of fame

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.7 / gh-1176
- Builds on: the foundation spec and the home, game, competition, player profile and news designs (all merged), and
  the shared components (`vm-panel`, `vm-sub`, `vm-label`), the profile's award badges and letter tile
- Status: autonomous run — no mockup round with the owner; decisions the owner may want to revisit are listed in the PR

## Why

`/hall` today is a maroon title and a grid of big cards: a 300 px photo (or `/img/nophoto.jpg`), the player's name,
then one grey box per award won — the icon with the season under it, or the bare title when the award has no icon. A
player who won the same award twice gets two identical boxes. Staff awards (Организатор, Главный судья) go to a
separate «Организаторы» grid and show as bare text.

Found while studying the real page (dev data: 59 award records, 21 players, 11 player awards with icons, 3 staff
awards without icons):

- the order of players is "whoever won something most recently first", and players awarded in the same season come in
  database order — not stable;
- Финчер's card has ten boxes for eight distinct awards (Любимый игрок and Почётный трупак twice each);
- an award without a competition (possible: the column is optional) shows the icon with no caption;
- long award titles («Вот это поворот! Автор самой эпичной ошибки») and long names («Девятый Игрок Фол (ДИФ)») wrap
  inside narrow boxes;
- judges and admins see exactly what visitors see — the page has no role-gated content;
- empty: «Скоро! Следите за обновлениями»; the «Организаторы» heading only when there are staff awards.

## Approaches

- **A. Restyle the player cards** — one card per player, same grouping, new look, the profile's award badges.
  Content and grouping stay. **Chosen.**
- **B. A table by award** — one row per award, its winners per season. A different page (new content, a matrix that
  needs sideways scrolling on phones); out of the epic's "keep content" rule.

## Goals

- Restyle the page in the warm paper look, behind `public_redesign`.
- One badge per award, like the player profile, so repeat wins read as one achievement with its seasons.
- A stable, meaningful order of players.

## Non-goals

- The old page (`new_design?` false renders exactly as today).
- The home page's hall of fame block (old home only).
- Admin screens for awards (Avo).

## Constraints

- Behind `public_redesign`: `HallOfFameController#show` renders `hall_of_fame/redesign/show` when `helpers.new_design?`.
- URL and existing i18n keys stay; new strings in both `ru.yml` and `en.yml` (under `hall_of_fame.redesign`).
- Reuse the shared components; no new rules on bare elements; no gold text.
- `spec/requests/hall_of_fame_spec.rb` and `spec/acceptance/hall_of_fame_spec.rb` keep passing against the old design.

## The page

- Title «Зал Славы» (existing `hall_of_fame.title`), serif page title.
- **Players**: a section labelled by a visually hidden `h2` («Игроки», `hall_of_fame.redesign.players`), so the
  headings go h1 → h2 → h3 like the organizers section; inside, a grid of cards — one column on phones, two from
  `sm`, three from `lg`. Card (`vm-panel`):
  - photo 56 px square (8 px radius, line border, `resize_to_fill`, empty `alt` since the name follows it), or the
    profile's letter tile (`aria-hidden`);
  - name as a link to the profile, semibold, wraps (no truncation);
  - a `vm-sub` line with the number of award records, pluralised («10 наград») — a repeat win counts each time, as on
    the profile header;
  - the award badges: the profile's badge partial, moved to `shared/redesign/_award_badges` and shared by both pages.
- **Order of players**: most award records first; ties keep today's order (most recent award first, then the award
  record entered first). The service's query gets `player_awards.id` as a final tie-breaker so today's order is
  stable.
- **Badges in a card**: one per award, in the awards' `position` order (awards without a position last, then id);
  the badge's sub line lists the seasons newest first, as the page loads them. An award without a competition has no
  sub line. This differs on purpose from the player profile, which puts staff badges first and then orders by the
  player's first win: the profile tells one player's story, the hall compares players, so the same award sits in the
  same place on every card. Both pages share `AwardBadge` and the badge partial; only the sort differs.
- **Organizers** (existing `hall_of_fame.organizers`), only when there are staff awards: a `vm-label` heading and the
  same cards, with the dark staff badges and **no** count line (the badge already says what they do).
- **Empty** (no awards at all): «Скоро! Следите за обновлениями» (existing `common.coming_soon`), muted.
- Nothing extra for judges or admins.

## Caching

The old cards are fragment-cached; the new ones are not. All records are preloaded by the service, and the page is
21 small cards, so the cache would save little and its key (awards, seasons, photo) is easy to get wrong. The old
fragments keep their keys; the new templates have their own paths, so the two designs never share a fragment.

## Data

`HallOfFameService::Result` keeps `player_awards` and `staff_awards` (old page) and gains `player_entries` and
`staff_entries`: one `Entry(player, player_awards)` per player, with `awards_count` and `badges`. `AwardBadge` moves out
of `PlayerProfileService` into its own value object so both services build the same badges. No extra queries.

## Testing

- Request spec `spec/requests/redesign/hall_of_fame_spec.rb` (`include_context "with the new design"`): page switch,
  title, card per player with link, photo vs letter tile, count line, player order (count, ties), one badge per award,
  badge order, seasons line, award without a competition, organizers section present / absent, empty state.
- Service spec for the entries (order, ties, badges, staff).
- Old specs keep passing.
- Evilution on changed Ruby (controller, service, value object).
