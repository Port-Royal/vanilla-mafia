# Public site redesign — foundation (design system and layout shell)

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.1 / gh-1170
- Page tasks that build on it: vm-bpk.2 – vm-bpk.9 (gh-1171 – gh-1178)
- Status: design for approval

## Why

The public site looks dated and home-made. The owner wants it **simple and stylish**, in the spirit of GitHub's
restraint — quiet surfaces, thin lines, compact tables that are easy to scan, one accent colour used sparingly — but
**not a copy of GitHub**. The accent comes from the club's own visual world: the warm gold of the League of Asia
"Chiang Mai Open" poster.

The maroon brand colour is a legacy of the old site and is **dropped** from the public site.

The epic was split (agreed with the owner) into this foundation task plus one task per page. This document covers
only the foundation: the look, the shared building blocks and the shared layout. Each page gets its own design round
later, starting from a close study of the real current page.

## Goals

- One visual direction, agreed: **"warm paper"** (option B of three shown in the mockups).
- A small design system in Tailwind that every page task reuses: colour and type tokens, spacing, and a handful of
  components (buttons, panels, tables, pills, tabs, breadcrumbs, rank medals).
- A new layout shell for the public site: a top bar instead of the left sidebar, a phone menu, a footer, the RU/EN
  switcher, the announcement toast and flash messages — phone first.

## Non-goals

- Restyling page content. Home, game, competitions, player, news, hall of fame, help and error pages are separate
  tasks (vm-bpk.2 – vm-bpk.9). This task may touch them only where the new shell forces it (see "Transition").
- Judge and admin screens (protocols, live protocol, breakdowns, Avo), the OBS overlay, mailers and the podcast. They
  are out of scope for the whole epic.
- Dark mode.
- A new logo.

## Anti-goals (would be a failure even if it "works")

- Looking like a GitHub clone (GitHub's exact greys, Primer components, Octicons, its header).
- Gold everywhere. Gold is an accent; most of the page is cream, brown-black and thin warm lines.
- Gold text on cream for anything that must be read (it fails contrast, see below).
- Breaking the judge/admin screens or the OBS overlay while changing shared CSS.

## Constraints (from the epic)

- URLs, content and i18n keys stay; every string stays in `ru.yml` / `en.yml`.
- Existing request, system and acceptance specs keep passing.
- No new JS framework: Turbo, Stimulus and importmap as now. Tailwind v4 via `tailwindcss-rails` as now
  (`app/assets/tailwind/application.css`, tokens in `@theme`).

## The look: "warm paper"

Reference mockups (throwaway, local only, not committed): `.artifacts.local/redesign-mockups/visual-direction.html`
(A/B/C, B chosen) and `pages-v1.html` (game, series and season pages as **draft examples only** — the page tasks decide the
final page designs).

Character: a cream page, deep brown-black text, warm thin borders, slightly lighter panels for cards and tables, serif
page titles, gold used for emphasis — the leader's row, the active tab, rank medals, the primary button's text, big
numbers. Calmer and more "club" than "app".

### Colour tokens

Defined in `@theme` in `app/assets/tailwind/application.css`. Names are the builder's call; values and roles are
decided. Contrast ratios are WCAG 2.x, measured.

| Role | Value | Use | Contrast |
|------|-------|-----|----------|
| paper | `#faf6ec` | page background, top bar background | — |
| panel | `#fffdf7` | cards, tables, toast | — |
| line | `#e6dcc4` | panel borders, top bar bottom border, table header rule | — |
| line-soft | `#f0e8d6` | row separators inside panels | — |
| ink | `#2a2418` | body text, links, headings, primary button background | 14.3 on paper |
| ink-muted | `#736650` | secondary text: meta lines, table headers, breadcrumbs, inactive nav | 5.2 on paper, 5.0 on gold-wash |
| label | `#86681f` | small uppercase section labels ("Идёт сейчас") | 4.9 on paper |
| gold | `#d9a21b` | **non-text only**: active-tab underline, leader/winner row edge, gold medal, link underline accents | 2.1 on paper — never text |
| gold-bright | `#f3c94f` | text on ink (primary button label, pill on dark) | 9.7 on ink |
| gold-soft | `#f3e2b0` | pill background (e.g. "Победа мирных") | text `#5c4000` on it: 7.5 |
| gold-wash | `#fbf1d6` | highlighted row background (winners, leader) | ink on it: 13.7 |
| silver / bronze | `#e3dccb` / `#e9cfae` | 2nd / 3rd rank medal fills, ink text on them | — |
| alert-soft / alert-ink | `#f5ddd5` / `#8a2a12` | red-side pills (mafia win), error flash | 6.7 |

The mockups used `#7d7058` for muted text; it is 4.49 on paper (just under AA), so it is replaced by `#736650`.

`--color-maroon` and `--color-row-alt` **stay defined**: the judge screens and the live protocol still use them and are
out of scope. No public-page component may use them once its page is restyled.

### Typography

- Body and UI: keep **Roboto** (already loaded from Google Fonts, full Cyrillic). 14 px base on phone and desktop for
  tables and UI, 16 px for running text (news articles, help pages).
- Page titles (`h1`) and article titles: a **serif with proper Cyrillic** — **PT Serif** 700 from Google Fonts
  (builder's call to swap for another Cyrillic serif if PT Serif renders poorly, e.g. Lora). Section headings inside a
  page stay sans.
- Section labels: 11–12 px, uppercase, letter-spacing ~0.06em, semibold, `label` colour.
- Numbers in tables: `tabular-nums`, right-aligned.

Type scale (builder may tune by a step): h1 28 px desktop / 22 px phone; h2 20 px; body 14/16 px; meta 12–13 px;
label 11–12 px.

### Spacing, radii, lines

- Page container: centred, max width ~72 rem (1152 px), side padding 16 px phone / 24 px desktop.
- Vertical rhythm between page sections: 32–48 px desktop, 24–32 px phone.
- Radius: 8 px for panels and tables, 6 px for buttons and chips, full for pills and medals.
- Borders 1 px; no drop shadows except the toast and open menus (one soft shadow).

## Scope of styles: opt-in, no new global element rules

No new global rules on `body`, `a`, `h1` etc. — they would reach the judge/admin screens and the unfinished public
pages, which share the `application` layout. The shell styles its own elements; page content gets the new look only
through the component classes below, which each page task switches on. (Today's global `font-sans` Roboto stays.)

## Which components this task builds

This task builds the tokens, the shell, and the components the shell itself uses: buttons, panel (toast, flash,
dropdown), links and focus ring inside the shell. The remaining components (table and its variants, pill, rank medal,
tabs, breadcrumbs, chip, section label) are **specified here and built by the first page task that needs them**, in
the shared stylesheet, so every component is built and tested against a real page instead of sitting unused.

## Components

Implemented as Tailwind `@layer components` classes in `app/assets/tailwind/application.css` (or as ViewComponents
where markup repeats with logic — builder's call; `app/components/` already exists). Class names below are
illustrative.

**New classes, not a restyle of old ones.** `.data-table` and `.scroll-wrapper` are also used by
`table_overlays` (OBS overlay) and the help pages; changing them in place would leak the new look into out-of-scope
screens or unfinished pages. Each page task switches its markup to the new classes; the old classes are deleted when
nothing uses them any more.

- **Button** — primary: ink background, gold-bright text, 6 px radius, semibold. Secondary ("ghost"): transparent,
  1 px `#d8cba9` border, ink text. Min height 36 px desktop, 44 px tap target on phone.
- **Panel / card** — panel background, 1 px line border, 8 px radius, no shadow.
- **Table** — inside a panel. Header: 10.5–11 px uppercase ink-muted, line bottom rule, no fill. Rows: 7–8 px vertical
  padding, line-soft separators, no zebra striping. Numbers right-aligned tabular. Hover: subtle gold-wash.
  Variants:
  - *highlight row* (winner / leader): gold-wash background + 3 px gold inset edge on the first cell (replaces today's
    green `bg-green-50` on the game page — that change happens in the game page task);
  - *wide table*: horizontal scroll inside the panel with the first column pinned (`position: sticky`), for the series
    matrix;
  - *phone fold*: a secondary line under a cell's main text (`.sub`, 11 px ink-muted) so a page can fold columns on
    phones instead of scrolling. Which columns fold is decided per page.
- **Pill / tag** — full radius, 11–12 px semibold. Gold-soft (civilian win, neutral highlight), alert-soft (mafia win),
  ink with gold-bright (strong emphasis).
- **Rank medal** — 18 px circle with rank number: gold (1), silver (2), bronze (3); ranks 4+ plain ink-muted number.
- **Tabs** — row of links on a line bottom border; active: ink, semibold, 2 px gold underline; inactive ink-muted.
  Plain links (each tab a URL or an anchor), no JS required.
- **Breadcrumbs** — 12 px ink-muted, links underlined with a gold-ish underline (`#e0cf9f`), `/` separators.
- **Chip** — small bordered box for game numbers and similar (panel background, line border, 6 px radius,
  tabular-nums).
- **Section label** — see Typography.
- **Links** — ink, underline on hover; in running text (news, help) always underlined with the gold-ish underline.
  Visible focus: 2 px ink outline with 2 px offset on every interactive element.

## Layout shell (`app/views/layouts/application.html.erb`)

Replaces the dark left sidebar with the textured background image (`/img/back.jpg`) and the dark mobile header.

### Top bar

- Full width, paper background, 1 px line bottom border. Content inside the page container width. Not sticky (builder's
  call to make it sticky if it feels right on phones).
- Left: logo, linking to `/`. The current logo `/img/chi_light.png` is light grey and disappears on cream; it is shown
  **darkened with a CSS filter** (mockups used `filter: invert(.86) sepia(.4)`), height ~28–32 px. A dedicated dark PNG
  is a later improvement, not required.
- Then the public nav, in today's order: featured competitions (`featured_competitions`), Hall of Fame, News. Active
  item: ink, semibold, 2 px gold underline; others ink-muted. "Active" is the narrow reading: the item is active only
  on its own page (`current_page?`, News also on `/news/:slug`). Games, players and child competitions mark nothing —
  no controller has to tell the layout where it belongs.
- Right: RU / EN switcher (current locale ink bold, other ink-muted, same `button_to` PATCH as today), then:
  - signed out: "Войти" as a ghost button;
  - signed in: a menu button that opens a dropdown with the role-gated links, exactly the same set and conditions as
    today (Podcast for subscribers/admins, Protocols, Breakdowns behind the `game_breakdown` toggle, Help, Manage news,
    Telegram, Admin, Notification settings), then Sign out. Stimulus, building on the existing `menu` controller.
- If the featured competitions do not fit on desktop, the overflow goes into the same menu (builder's call how —
  a "More" item is fine).

### Phone (below `lg`)

- Bar shows logo left and a menu button right (44 px tap target).
- The menu opens a full-width panel under the bar with every link: public links first, then role links, then sign in /
  sign out, then RU / EN — the same content and order as today's mobile nav. Same `menu` Stimulus controller and ARIA
  (`aria-expanded`, `aria-controls`).

### Main area

- Centred container (see Spacing), no sidebar. Flash messages at the top of main, restyled as panels (alert colours for
  errors).

### Footer

There is no footer today. Add a quiet one: line top border, ink-muted 12–13 px, club name and current year, and the
public links (Hall of Fame, News). Exact contents are the builder's call within that spirit; any new text goes into
`ru.yml` / `en.yml`.

### Announcement toast

Same behaviour and Stimulus controller (`announcement-dismiss`), same position (bottom right; full width minus 16 px
gutters on phones). Restyled: panel background, line border, one soft shadow, title in ink semibold (no maroon), close
button with a 44 px tap target on phones.

### Unchanged

`focus.html.erb` (live protocol) and `overlay.html.erb` (OBS) layouts are not touched.

## Transition

**Decided by the owner: the redesign ships behind a feature toggle.** Work merges step by step; visitors keep seeing
today's site until the owner switches the toggle on.

- New key `public_redesign` in `FeatureToggle::KEYS`, set through Avo like the other toggles (no data migration). It
  has three modes, held in the toggle's existing `value` column while `enabled` is true:

  | Toggle | Who sees the new design |
  |--------|-------------------------|
  | no row, or `enabled: false` | nobody; no offer shown (default) |
  | `enabled: true`, `value: "opt_in"` | visitors who chose it; everyone else sees the old design plus an offer |
  | `enabled: true`, `value: "everyone"` | everyone, mandatory; no offer, no way back |

  An unknown or blank `value` with `enabled: true` behaves as `opt_in` (the safer of the two).

- **The visitor's choice** is a cookie, following the locale switcher's pattern (`LocalesController#update`): a
  `design` cookie (`new` / `old`), 1 year, set by a small PATCH endpoint (e.g. `DesignPreferencesController#update`)
  and `redirect_back`. Works the same for anonymous and signed-in visitors; not stored on the user.
- **The offer** (opt-in mode, no choice made yet): a slim, dismissible strip at the top of the old layout — "There's a
  new design — want to try it?" with "Try it" (sets `new`) and "No thanks" (sets `old`, strip never shows again).
  Text in `ru.yml` / `en.yml`.
- **The way back** (opt-in mode, `new` chosen): a "Back to the old design" link in the new footer (sets `old`). After
  going back, the strip does not reappear; the visitor can still return to the new design through a small "New design"
  link in the old layout's sidebar (builder's call on exact placement).
- One helper decides per request, e.g. `new_design?` → `everyone` mode, or `opt_in` mode with cookie `new`. Layout and
  page templates ask only that helper, never the toggle directly.
- **Off / old:** the current layout renders exactly as today, apart from the offer strip and the "New design" link —
  the sidebar markup is kept unchanged (moved to a partial is fine). **New:** the new shell renders.
- The choice switches the whole shell for every page on the `application` layout, judge/admin screens included (they
  keep their own maroon content inside the new shell).
- Fragment caches whose markup differs between designs must include the design in the cache key (today:
  `hall_of_fame/_player_card`, `hall_of_fame/_award` — handled by the hall of fame task).
- Each page task follows the same rule: when its page is restyled, the old page markup still renders with the toggle
  off and the new markup with it on. Specs cover both states.
- After all page tasks land and the toggle is switched on for good, a cleanup task (vm-bpk.10) removes the toggle, the
  old shell, the old page markup and the unused old CSS (`.data-table`, `.scroll-wrapper` where nothing uses them).
- Previewing before anyone is offered the design: locally, or by switching to `opt_in` and opting in.

## Testing

- Existing request, system and acceptance specs pass; update only selectors tied to the old shell (e.g. ids like
  `site-sidebar`, `site-mobile-header`) and keep equivalent ids on the new elements.
- New specs for the shell: role-gated links appear exactly for the same users as today (signed out, subscriber, judge,
  news manager, admin), on desktop menu and phone menu; locale switcher works; toast still dismisses.
- Stimulus changes: Vitest tests under `test/javascript/`, Stryker on the changed controller. `menu_controller.js`
  has no Vitest test yet and today drives a single `nav` target from `<body>`; the desktop dropdown and the phone panel
  need two instances.
- Ruby changes (helpers, components): RSpec + evilution per the project workflow.
- Manual check at 375 px, 768 px and 1280 px widths.

## Left to the builder

- Token and class names; Tailwind classes vs ViewComponents.
- Exact type sizes within one step of the scale; PT Serif vs another Cyrillic serif.
- Sticky or static top bar; how nav overflow is handled on desktop.
- Footer contents within the stated spirit.
