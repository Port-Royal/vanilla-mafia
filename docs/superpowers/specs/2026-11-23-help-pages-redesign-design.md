# Public site redesign — help (index and page)

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: gh-1177
- Builds on: the foundation spec and the home, game, competition, player profile and news designs (all merged), and the
  shared components (`vm-panel`, `vm-table`, `vm-label`, tokens `ink-muted`, `gold-line`, `line-soft`, …)
- Status: autonomous run — no mockup round with the owner; decisions below are the builder's, listed for review

## Why

`/help` is a bare list of maroon links with a grey summary. `/help/:slug` is a maroon breadcrumb, a maroon title and
the page partial: maroon `h2`s, `list-inside` numbered/bulleted lists, grey `pre` boxes and the old `.data-table`.
The pages are long reference texts read by judges and admins (the menu shows «Справка» only to them), some of them
very long (the live protocol page: 7 sections and 7 key tables) with no way to jump to a section.

Current state studied:

- Pages: `obs-overlay` and `podcast-feed` always; `game-breakdown` and `live-protocol` only with their feature
  toggle on (hidden from the list and 404 otherwise). The index is never empty.
- No data from the database and no per-role content: the page is the same for every visitor; the URL is public,
  only the menu entry is role-gated. Titles are short fixed i18n strings; the long items are the URL examples in
  `pre` boxes and long paragraphs.
- Linked from the judge protocol form (overlay help), the podcast page (feed help) and the role menu.

## Goals

- Restyle both pages in the warm paper look, behind `public_redesign`.
- Comfortable reading of long instructions: a reading column, 16 px running text, sans section headings.
- Jumping to a section on the long pages: a contents list.

## Non-goals

- The help texts themselves (content and i18n keys stay; no rewording).
- The old pages (`new_design?` false → exactly as today, old partials untouched).
- Who may open help (controller rules stay, toggled pages stay hidden).
- The links on the home page's documents block to `league-rules` / `game-rules` / `rating-system` (not help pages,
  they 404 today — separate issue).

## Constraints

- Behind `public_redesign`: `HelpController#index` and `#show` render `help/redesign/index` / `help/redesign/show`
  when `helpers.new_design?`.
- The four page bodies get redesigned copies in `help/redesign/pages/_<slug>.html.erb`, reusing the existing keys
  (`t("help.pages.<slug>.…")`); the old partials stay for the toggle-off state and are removed by the cleanup task.
- New strings (only the contents label) in both `ru.yml` and `en.yml`, under `help.redesign`.
- No new JS; no new global element rules; no maroon, no gold text.

## Index — `/help`

- Serif page title «Справка» (existing `help.index.title`), 22/28 px like the other pages.
- One `vm-panel`, one row per available page (`line-soft` separators), in today's order:
  - title as a link (semibold, ink) to the page — the whole row is the link, so the tap target is the full row;
  - summary under it, muted, 13 px;
  - a chevron «›» on the right, muted, decorative (`aria-hidden`).
- No empty state: two pages are always available.

## Page — `/help/:slug`

- Breadcrumb as on the game/competition pages: «Справка» (link, muted, gold-line underline) / current title
  (`aria-current="page"`).
- Serif `h1` with the page title.
- Layout: on `lg` two columns — the text column (max 680 px) and a narrow sticky aside with the contents; on phones the
  contents come first, above the text, as a compact panel.
- **Contents** («Содержание», new key `help.redesign.contents`, `vm-label`): a list of anchor links to the page's `h2`
  sections, in order. The headings are written through a small helper, `help_heading(anchor, text)`, that renders the
  `h2` with an `id` and records it; the show template renders the body first and the contents from what was recorded,
  so the list can never drift from the headings. Shown only when the page has two or more sections (all four do).
  Anchors come from the i18n key stems (`setup`, `keys`, `pocket-casts`, …), stable across locales.
- **Body** (`help-prose` wrapper, scoped like `news-prose`):
  - intro paragraph slightly larger, ink;
  - `h2` 20 px semibold sans, ink, with top spacing and `scroll-margin-top` so a jump does not hide it;
  - `h3` (live protocol stages) 15 px semibold;
  - numbered steps as an `ol` with outside markers (not `list-inside`), bullets the same;
  - URL examples as a mono code block: panel background, line border, 6 px radius, horizontal scroll inside the box,
    never page scroll;
  - tables (OBS recommended settings and display settings, live protocol keys) in a `vm-panel` with `vm-table`; key
    cells as a small mono key cap (line border, panel background), `whitespace-nowrap`; wide tables scroll inside the
    panel.
- Not found / toggled off → 404 as today.

## Testing

- Request spec `spec/requests/redesign/help_spec.rb` (`include_context "with the new design"`), both toggle states:
  - index: title, rows in order with links and summaries, toggled pages listed / hidden;
  - page: breadcrumb, title, contents links matching the `h2` ids in order, every section heading of every page,
    key tables, code blocks, toggled pages 404, unknown slug 404; the old markup when the design is off.
- Helper spec for `help_heading` / `help_sections`.
- `spec/requests/help_spec.rb` keeps passing against the old design.
- Evilution on the controller and the helper.
- Manual check at 375, 768, 1280 px.
