# Public site redesign — home page

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.2 / gh-1171
- Builds on: the foundation (`docs/superpowers/specs/2026-11-18-public-site-foundation-design.md`, merged in #1189–#1196)
- Related: vm-6qa4 / gh-1198 — (EPIC) Upcoming events
- Status: design for approval

## Why

The home page today stacks up to nine blocks one under another: intro, what's new, running tournaments, recently
finished, recent games, news, Hall of Fame, stats and documents. A visitor on a phone scrolls past an intro and site
release notes before reaching anything they came for.

The owner says what visitors come for, in order:

1. **The next event** — the next club game session or an upcoming tournament. This is the most important thing.
2. **Recent results** — last games, finished tournaments, minicups and series, plus the running tournaments' leaders.
3. **News.**

Everything else either moves to its own page (Hall of Fame, stats, documents) or goes away (intro, "what's new").

## Goals

- A home page with three parts: the next event at the top, then **Results** and **News** side by side (stacked on
  phones).
- Built in the warm paper look on top of the foundation, behind the `public_redesign` toggle.
- Leave a clean slot at the top for the upcoming-events block, which the Events epic (#1198) fills later.

## Non-goals

- The events feature itself: event data, admin, Telegram poll, `/events` page — all in #1198.
- New pages for stats and documents (separate tasks, see "Follow-up tasks").
- Changing the old home page.

## Anti-goals

- The page looking empty or broken while there is no event block yet.
- Losing a block that admins can switch off today without them noticing (see "Block toggles").

## Constraints

From the epic and the foundation:

- Ships behind `public_redesign`: views ask `new_design?`. When it is false the old home page renders exactly as
  today; when true, the new one.
- URLs, content and i18n keys stay; new strings go into both `ru.yml` and `en.yml`.
- Existing request, system and acceptance specs keep passing; new specs cover both designs where behaviour differs.
- No new JS framework.
- New look only through the foundation's opt-in classes and tokens; components the foundation specified but did not
  build (pill, rank medal, section label) are built here, the first page that needs them, in the shared stylesheet.

## Layout

Reference mockup (throwaway, local): `.artifacts.local/redesign-mockups/home-v1.html`.

### Top: next event (slot only in this task)

- The owner decided: the event block replaces the intro, and it is the first thing on the page.
- This task renders **nothing** in that slot and adds no event code. It leaves a clearly named place in the template
  (e.g. a partial render guarded by a single condition that is false until #1198) so the Events epic can drop its
  block in without touching the rest of the page.
- Until then the page starts with the two columns. No placeholder, no empty box.

For the record, the mockup's event block (to be designed properly in #1198): event type, title, date, time and
place, the Telegram poll with a "Vote in Telegram" button for club sessions, and a row of the next two or three events.

### Two columns: Results (left) and News (right)

On `lg+`: two columns, Results a little wider (about 55/45). Below `lg`: one column, Results first, then News.

**Results** column, top to bottom:

1. **Running now** — one panel per running root competition (`Competition.roots.running.ordered`, as today): the
   competition name linking to its page, a "table →" link, and the top 5 players with rank medals (gold, silver,
   bronze for 1–3, plain number after) and their rating. Same data as today's mini standings.
2. **Recently finished** — up to 3 finished root competitions (seasons, series, minicups, tournaments — whatever
   `Competition.roots.recently_finished` returns today), each a row: name linking to the competition, end date,
   winner linking to the player.
3. **Recent games** — the last games (`Game.finished.recent`, as today): game name linking to the game, its series,
   date, judge, and a result pill — civilians win in gold-soft, mafia win in alert-soft, draw in a neutral pill
   (panel background, line border, ink text) — plus an "all games" link if a sensible target exists (otherwise omit
   the link; builder's call). Pill text reuses the existing result labels (`activerecord.attributes.game.results.*`:
   «Победа мирных», «Победа мафии», «Ничья»), not the mockup's short labels, so no new keys are needed. The neutral
   pill is the third variant of the shared pill component.

**News** column: the latest 3 visible news (as today), each with:

- a small thumbnail of the first photo when the article has photos (no thumbnail otherwise);
- title linking to the article;
- date (and the author's player name when the author is a claimed player, as on the news page);
- the first lines of text — a short plain-text excerpt (`News#truncated_content` exists; length is the builder's
  call, about two lines).

Plus an "all news" link to `/news`.

Section labels are the foundation's small uppercase gold-brown labels. Rows sit in panels with thin warm separators.

### Removed from the new home page

Decided by the owner:

- **Intro** (logo, "Vanilla Mafia", "Клуб спортивной мафии", "current tournament" button) — the event block takes its
  place.
- **What's new** (site release notes) — the announcement toast still shows them, but only when `toast_whats_new` is
  enabled. Decided by the owner: with only `home_whats_new` on, release notes are simply not shown on the new home
  page; the admin enables `toast_whats_new` if they want them. No change to the toast or the layout.
- **Hall of Fame, stats, documents** — they become their own pages reachable from the menu (Hall of Fame already
  has one).

The old home page keeps all nine blocks unchanged.

## Block toggles

Today each block can be switched off with a `home_<block>` feature toggle (shown unless the toggle exists and is
disabled). In the new design:

- `home_running_tournaments`, `home_recently_finished`, `home_recent_games`, `home_latest_news` keep working: a
  disabled block is not shown.
- `home_hero`, `home_whats_new`, `home_hall_of_fame`, `home_stats`, `home_documents` have no effect on the new page
  (those blocks aren't there). They keep working for the old page.
- If every Results block is disabled, the Results column is not rendered and News takes the full width; and the
  other way round. If everything is disabled, the page is just empty below the top bar (acceptable — admin's choice).
- The controller should not load data for blocks the new design doesn't show (Hall of Fame, stats).

## Empty states

- No running competitions → "Running now" is omitted.
- No finished competitions / no finished games → that sub-block is omitted.
- No news → the News column is omitted and Results takes the full width.
- All empty (fresh install) → empty page below the top bar; acceptable.

## Testing

- Request specs for the new home page with `include_context "with the new design"`: the two columns and their
  contents, medals, result pills, news thumbnail and excerpt, each block toggle, empty states, removed blocks absent.
- The existing `spec/requests/home_spec.rb` keeps passing unchanged against the old design (toggle off by default).
- Mutation testing on any changed Ruby (controller, helpers) per the project workflow.
- Manual check at 375, 768 and 1280 px.

## Follow-up tasks (to create in the epic)

- **Stats page** — players, games and competitions counts, reachable from the menu.
- **Documents page or menu item** — today three links to help pages (league rules, game rules, rating system).
  Note: the help index link in the menu is shown only to users who `can_view_help?`; the three rules pages are linked
  publicly from the old home page. The new route to them must stay public.

## Left to the builder

- Exact column ratio, spacing and type sizes within the foundation's scale.
- Excerpt length, thumbnail size and crop.
- The "all games" link target, or no link.
- How the event slot is marked in the template.
