# News Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigned `/news` (card list) and `/news/:slug` (reading page with related links) shown when `new_design?`;
old pages unchanged otherwise.

**Architecture:** `NewsController#index` / `#show` render `news/redesign/index` / `news/redesign/show` for HTML when
`helpers.new_design?`; the infinite-scroll turbo stream picks the card partial by the same check. Queries, visibility,
order and paging toggles are untouched. One helper method builds the article's related links.

**Tech Stack:** Rails 8.1, Tailwind v4, Stimulus (existing `infinite-scroll`, `lightbox`), pagy, RSpec, evilution.

**Spec:** `docs/superpowers/specs/2026-11-22-news-pages-redesign-design.md` (ships with this PR).

## Global Constraints

- Old pages unchanged: `spec/requests/news_spec.rb` passes untouched.
- New-design specs use `include_context "with the new design"`.
- Reuse `vm-panel`, `vm-sub`, `vm-pill`, `vm-btn vm-btn--ghost|--primary`, tokens `ink`, `ink-muted`, `line-soft`,
  `gold-line`, `gold-bright`; `format_date`; `news_photo_variant`. No new rules on bare elements; no gold text; no JS
  changes.
- Existing keys reused: `news.index.title|empty|edit|read_more|loading|load_error`, `news.show.back`. New strings in
  both locales under `news.redesign`.
- No `&.`, no `and return`; specs: `let_it_be`/`let`, nested contexts, no variables inside `it`.
- Git writes only with the owner's permission.

## Review Focus

1. Article without a claimed author (`author.player` nil) — no author link, no crash, on both pages. → Tasks 1, 2.
2. Article whose photos are all non-variable (e.g. unsupported type) — no thumbnail, no empty photo block. → Tasks 1, 2.
3. Article with empty rich text — card shows no excerpt paragraph, page shows no empty prose wrapper error. → Task 1.
4. Infinite scroll second page as turbo stream under the new design — appends new cards, not old articles. → Task 1.
5. Linked game whose competition is a season (not a series) — chip still «<name> · Игра N». → Task 2.

---

### Task 1: News list

**Files:**
- Modify: `app/controllers/news_controller.rb`, `app/views/news/index.turbo_stream.erb`, both locale files
- Create: `app/views/news/redesign/index.html.erb`, `app/views/news/redesign/_card.html.erb`,
  `app/views/shared/redesign/_pagy_nav.html.erb`
- Test: `spec/requests/redesign/news_spec.rb`

**Interfaces:**
- Controller: `format.html { render "news/redesign/index" if helpers.new_design? }` — keep the existing
  `respond_to`; `#show` gets `render "news/redesign/show" if helpers.new_design?` in Task 2.
- `news/redesign/_card` local: `card` (a `News`). Markup hooks for specs: `article[data-news-id]`, title link
  `h2 a`, meta `[data-part='meta']`, author link `[data-part='author']`, competition link
  `[data-part='competition']`, tags `.vm-pill`, image `img[data-part='thumbnail']`, excerpt `[data-part='excerpt']`
  (absent when blank), read-more `[data-part='read-more']` (class `hidden lg:inline`), edit `[data-part='edit']`.
- Excerpt: `card.truncated_content(250).to_plain_text`, `line-clamp-3 lg:line-clamp-none`.
- `index.turbo_stream.erb`: `render partial: (new_design? ? "news/redesign/card" : "news/article"), collection:
  @news, as: (new_design? ? :card : :article)`; the sentinel markup is unchanged.
- Redesigned list wrapper: `#news-list` turbo frame (infinite) or `div#news-list` (other modes), inside a `vm-panel`
  with `divide-y divide-line-soft`; sentinel outside the panel, same data attributes as today.
- `shared/redesign/_pagy_nav` local `pagy:`; same structure and aria labels as `shared/_pagy_nav`, current page
  `aria-current="page"` with `bg-ink text-gold-bright`, links `vm-btn vm-btn--ghost`-like.

- [ ] **Step 1: Write failing request specs** — contexts: page switch (design off → no `article[data-news-id]`);
  cards in `recent` order; title links to `news_path`; meta with `format_date` date, author link to
  `player_path` when claimed and absent when not; competition link when linked; tag pills when tagged; thumbnail only
  when a variable photo exists (one with a non-image attachment → no `img`); excerpt for a 600-char two-paragraph text
  equals `truncated_content(250).to_plain_text`, empty content → no excerpt element; read-more link present; edit link
  only for an editor; empty state text `news.index.empty`; classic mode (`news_classic_pagination` on,
  `news_per_page` 2, 3 news) → nav with `aria-current="page"` on «1»; infinite mode → `turbo-frame#news-list` and the
  sentinel `data-next-url`; infinite second page as `turbo_stream` → response contains `data-news-id`, not the old
  `border-b border-neutral-200` article; none mode → all cards; `news_max_article_length` 30 has no effect on the
  excerpt.
- [ ] **Step 2: Run** `NO_COVERAGE=1 bundle exec rspec spec/requests/redesign/news_spec.rb` — FAIL (old page).
- [ ] **Step 3: Implement** controller switch, views, turbo stream switch, pagy nav partial.
- [ ] **Step 4: Run** the new spec and `spec/requests/news_spec.rb` — PASS; `bin/rails tailwindcss:build` OK.
- [ ] **Step 5: Commit** (ask first) — `feat: redesigned news list`.

### Task 2: Article page

**Files:**
- Modify: `app/controllers/news_controller.rb` (`#show` switch; preload `{ author: :player }, :tags,
  :rich_text_content, :competition, { game: :competition }, :mentioned_players, photos_attachments: :blob`),
  `app/helpers/news_helper.rb`, both locale files
- Create: `app/views/news/redesign/show.html.erb`
- Test: `spec/requests/redesign/news_spec.rb`, `spec/helpers/news_helper_spec.rb` (create or extend)

**Interfaces:**
- `NewsHelper::RelatedLink = Data.define(:kind, :label, :path)`;
  `NewsHelper#news_related_links(news) -> Array<RelatedLink>` in order: competition (`kind: :competition`, its name,
  `competition_path(slug:)`), game (`:game`, `t("news.redesign.game", competition: game.competition.name, number:
  game.game_number)`, `game_path(game)`), then each of `news.mentioned_players` ordered by mention `id` (`:player`,
  name, `player_path`). Missing links are skipped.
- i18n `news.redesign`: `related.competition` «Турнир» / "Competition", `related.game` «Игра» / "Game",
  `related.player` «Игрок» / "Player", `game` «%{competition} · Игра %{number}» / "%{competition} · Game %{number}".
- Page hooks: `article#news-article`, back link `[data-part='back']` → `news_index_path` with `news.show.back`,
  `h1`, meta `[data-part='meta']`, edit `[data-part='edit']` (`vm-btn vm-btn--ghost`), hero photo link
  `[data-part='hero']` (`:full` image, href `:zoom`, `data-controller="lightbox"`, `aria-label` title), thumbnails
  `[data-part='thumbnail']` (96×72), body `.news-prose` wrapper `[data-part='body']`, related list
  `[data-part='related']` with `li[data-kind]` items (caption + label link). No heading on the related block.
- Body styling: utility classes on the wrapper (`text-base leading-[1.65] [&_p]:my-3.5 [&_a]:underline
  [&_a]:decoration-gold-line [&_a]:underline-offset-3`), no new global rule.

- [ ] **Step 1: Write failing specs** — helper: each kind present/absent, order competition → game → players by
  mention id (create mentions in reverse name order), game label for a game in a season. Request: title, back link,
  meta date/author link (and no link when unclaimed), tag pill, edit button only for an editor, hero is the first
  variable photo with zoom href, other photos as thumbnails, no photo block without photos, body text present,
  related block items per kind, no related block and no rule when nothing is linked, draft → 404.
- [ ] **Step 2: Run** the request and helper specs — new examples FAIL.
- [ ] **Step 3: Implement** helper, show switch with preloads, view, i18n.
- [ ] **Step 4: Run** new specs and `spec/requests/news_spec.rb`; `bundle exec rubocop` on changed Ruby — PASS / no
  offences.
- [ ] **Step 5: Commit** (ask first) — `feat: redesigned news article page`; include the spec and this plan.

### Task 3: Verification

- [ ] **Step 1:** Full suite without system specs — 0 failures; `npm test` passes.
- [ ] **Step 2:** Evilution (`NO_COVERAGE=1`, `--jobs 1`) on `app/helpers/news_helper.rb`
  (`--spec spec/helpers/news_helper_spec.rb,spec/requests/redesign/news_spec.rb`) and
  `app/controllers/news_controller.rb` (`--spec spec/requests/news_spec.rb,spec/requests/redesign/news_spec.rb`); kill
  survivors or record why equivalent; append to `.artifacts.local/regular-evilution-feedback.log`.
- [ ] **Step 3:** Whole-branch review by a fresh reviewer; fix Critical/Important with a failing test first.
- [ ] **Step 4:** PR only when the owner says so (`Closes #1175`, bead vm-bpk.6; no mutation results on GitHub).
