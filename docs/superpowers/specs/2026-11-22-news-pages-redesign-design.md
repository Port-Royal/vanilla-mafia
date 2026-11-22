# Public site redesign — news list and article

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.6 / gh-1175
- Builds on: the foundation spec and the home, game, competition and player profile designs (all merged), and the
  shared components (`vm-panel`, `vm-sub`, `vm-pill`, `vm-label`, `vm-btn*`, tokens `gold-line`, `ink-muted`, …),
  the news card partial `shared/redesign/_news_cards`, `format_date`, `NewsHelper#news_photo_variant`
- Status: mockup approved by the owner ("good"), after two changes (no «Связано» heading, no previous/next block)

## Why

`/news` today renders every article in full (title, meta, tags, inline photos, the text cut by the
`news_max_article_length` toggle, «Читать далее»), one after another, paged by toggles (none, classic pages or
infinite scroll). Long texts make it heavy to scan. `/news/:slug` shows «Назад», the title, meta, full-size photos with
a zoom and the text — and hides what the article is linked to: a competition, a game and mentioned players are stored
but never shown.

Dev data: 51 published news, text 89–956 characters, 2 with a photo (1 each), no tags, every author has a claimed
player; 2 news linked to a competition, none to a game, no player mentions (the feature exists, data does not yet).

## Approaches

- **A. Restyle the full-article stream** — length and paging toggles keep working as today; heavy to scan.
- **B. A list of cards** — thumbnail, title, date and author, an excerpt; paging toggles stay;
  `news_max_article_length` no longer applies on the new page. Matches the news cards on the home and competition
  pages. **Chosen by the owner.**

## Goals

- Restyle both pages in the warm paper look, behind `public_redesign`.
- A list that is quick to scan.
- A comfortable reading page that links to what the article is about.

## Non-goals

- Admin news screens (`admin/news/*`), the news editor, mailers.
- The old pages (`new_design?` false → exactly as today).
- Changing which news are visible (`News.visible`) or their order (`recent`).
- Previous / next navigation between articles (shown in the mockup, removed by the owner).

## Constraints

- Behind `public_redesign`: `NewsController#index` and `#show` render `news/redesign/index` / `news/redesign/show` when
  `helpers.new_design?`; the infinite-scroll turbo stream renders the new cards too when `new_design?`.
- URLs and existing i18n keys stay; new strings in both `ru.yml` and `en.yml` (under `news.redesign`).
- The three paging modes keep working on the new list (toggles `news_classic_pagination`, `news_infinite_scroll`,
  `news_per_page`), with the existing `infinite-scroll` and `lightbox` Stimulus controllers. No new JS framework.
- Reuse the shared components; no new rules on bare elements; no gold text.
- `spec/requests/news_spec.rb` keeps passing against the old design.

## Reference

Mockup (throwaway, local): `.artifacts.local/redesign-mockups/news-v1.html`.

## List — `/news`

- Title «Новости» (existing `news.index.title`), serif page title.
- One `vm-panel`, one card per article, separated by `line-soft` rules. Card:
  - **Photo** on the left when the article has a variable photo (the first one, `:card` variant, 160×120 desktop,
    80×60 phone, `alt=""` — the title is next to it). No placeholder when there is no photo.
  - **Title** (`h2`, 16 px desktop / 14.5 px phone, semibold) linking to the article.
  - **Meta line** (`vm-sub`): date (`format_date(published_at)`) · author's player name linking to the player profile
    (only when `author.claimed_player?`) · the linked competition's name linking to the competition (when present).
    Tags, when present, follow as `vm-pill`s.
  - **Excerpt**: `News#truncated_content(250).to_plain_text`, as the home cards do with 160 (builder's call, settled
    after the builder check): that method keeps whole paragraphs, then whole sentences, and cuts at a word only when
    the first sentence alone is too long — so an excerpt can be much shorter than 250 characters, and that is fine.
    No new excerpt method. On phones clamp it to three lines (CSS `line-clamp-3`, not a second excerpt).
  - **«Читать далее»** (existing `news.index.read_more`) under the excerpt on desktop only; on phones the title is the
    link.
  - **«Редактировать»** (existing `news.index.edit`), a small muted link at the right end of the meta line, only for
    `current_user.can_manage_news?`, to `edit_admin_news_path`.
- `news_max_article_length` is ignored on the new list (owner's pick).
- **Paging**, same modes and conditions as today:
  - infinite: the list is the `news-list` turbo frame; the sentinel shows «Загрузка...» (existing
    `news.index.loading` / `load_error`); the turbo stream appends new cards. The `infinite-scroll` controller writes
    that message itself, centred in `text-neutral-400`; it is left unchanged (builder's call — close enough to muted;
    no JS change, no new CSS);
  - classic: a pagination nav in the new look — a redesigned copy of `shared/_pagy_nav` (new partial
    `shared/redesign/_pagy_nav`; `shared/_pagy_nav` stays for admin news and podcast); current page ink background with
    gold-bright text, others ghost;
  - none: all cards.
- **Empty**: «Новостей пока нет.» (existing `news.index.empty`), muted.

## Article — `/news/:slug`

- A reading column, max ~680 px, left-aligned in the page container.
- Back link at the top: existing `news.show.back` («← К новостям»), muted, gold-line underline.
- **Title** `h1`, serif, 30 px desktop / 23 px phone.
- **Meta line**: date · author's player name (link to the profile, when claimed) · tags as pills. For editors, a ghost
  «Редактировать» button at the right end of the line (wraps under on phones).
- **Photos** (only variable ones, as today): the first one large — full column width, `:full` variant, rounded; the
  rest as 96×72 thumbnails in a row under it. Every photo opens the zoom (`:zoom` variant) through the existing
  `lightbox` controller, with the article title as the link's `aria-label`, as today.
- **Text**: the rich text, 16 px (15.5 px phone), line-height ~1.65, paragraphs spaced; links inside underlined with
  the gold-line underline. Scoped to the article body (a class on its wrapper), not global.
- **Related links** under the text, **without a heading** (owner's change): a thin line rule above, then chips, each
  with a small muted caption above the name:
  - «Турнир» → the linked competition (`competition_path(slug:)`), when present;
  - «Игра» → the linked game, labelled «<the game's own competition name> · Игра N» whatever that competition's kind
    (`game_path`), when present;
  - «Игрок» → each mentioned player (`mentioned_players`, in the order the mentions were created — `id`; there is no
    position column), linking to the profile.
  Captions are generic and do not change with the competition's kind: «Турнир» covers a season too, as the profile's
  «По турнирам» does (builder's call).
  No links → no block and no rule. Captions are new keys.
- No previous / next block (owner's change).
- Not found / not visible → 404 as today.

## Testing

- Request spec `spec/requests/redesign/news_spec.rb` (`include_context "with the new design"`):
  - list: cards in `recent` order, title links, meta (date, author link only when claimed, competition link when
    linked, tag pills), photo only when present, excerpt cut and ellipsis, «Читать далее», edit link only for news
    managers, empty state; each paging mode (classic nav with the new partial, infinite sentinel, none) and the turbo
    stream response rendering new cards;
  - article: title, back link, meta, edit button only for news managers, first photo large + other thumbnails with
    zoom links, text, related chips (each kind present / absent, no block when none), 404 for a draft.
- `spec/requests/news_spec.rb` keeps passing against the old design.
- Evilution on changed Ruby (controller, any helper), per the project workflow.
- Manual check at 375, 768, 1280 px.

## Left to the builder

- Whether the card list markup is shared with `shared/redesign/_news_cards` (different sizes and extras — probably a
  separate partial).
- Rich-text styling details inside the article body (lists, quotes, attachments) within the type scale.
