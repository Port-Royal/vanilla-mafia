# Public site redesign — documents

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: gh-1200
- Builds on: the foundation spec, the home page design (its "Follow-up tasks" asked for this) and the help and news
  pages (`vm-panel` row list, breadcrumb, `news-prose` reading column)
- Status: decided by the builder in an autonomous run (no mockup round with the owner)

## Why

The old home page had a «Документы» block: three links to `help_path("league-rules" | "game-rules" | "rating-system")`.
The redesigned home page dropped it, and the owner wants documents reachable from the menu.

Those three help slugs were never in `HelpController::PAGES`, so the links always answered 404, and no rules text
exists anywhere in the repository. There is nothing to move; the documents have to be written. So they become records
the admins write and publish themselves, instead of help partials a developer would have to commit.

## Model

`Document`: `title` (required), `slug` (required, unique, lowercase Latin letters, digits and single hyphens; generated
from the transliterated title through `Sluggable` when left blank), `body` (ActionText rich text, like `News#content`),
`position` (integer, default 0) and `published` (boolean, default false). Indexes: unique `slug`;
`(published, position, id)` for the public list. Scopes: `published`, `ordered` (`position`, then `id`).

Admins manage documents in Avo (`Avo::Resources::Document`: title, slug with a format hint, position (the column
default 0 fills it, so an Avo "next free position" default would never apply), published, body as a Trix field). Avo is already restricted to admins by the route constraint and
`authenticate_with`, like the other resources.

## Pages

Both public: no sign-in, no role check — the old block was public, unlike the Help link that only
`can_view_help?` users see.

- `GET /documents` (`documents_path`) — title «Документы» (serif, like the help index), then one `vm-panel` with a row
  per published document in `ordered` order, each the title and a `›`, linking to the document. No published
  documents → «Скоро! Следите за обновлениями» (`common.coming_soon`), muted.
- `GET /documents/:slug` (`document_path`) — a 680px reading column: breadcrumb «Документы / <title>», serif title,
  the body in `news-prose` (the news article styles for Trix content). A published document without text shows the
  `common.coming_soon` line instead of an empty body. A draft or unknown slug → 404 (the app's not-found page).

## Menu

«Документы» / «Documents» (`nav.documents`) after «Статистика» in the top bar, the phone menu and the footer. The link
is always shown: hiding it until a document is published would add a query to every page for a link that the owner
is about to fill, and the empty list says «coming soon». Active state: `nav_active?` marks it on the list and, like
News, on its documents (`/documents/...`).

## Seeds

`db/seeds.rb` creates three unpublished drafts with titles only — «Регламент лиги» (`league-rules`), «Правила игры»
(`game-rules`), «Система рейтинга» (`rating-system`) — idempotently by slug. No rules text is invented. Production
does not run seeds on deploy; there the owner creates the documents in Avo (the slug hint suggests the same slugs).

## Testing

- `spec/models/document_spec.rb`: validations, slug format and generation, defaults, rich text body, scopes.
- `spec/requests/documents_spec.rb`: list (published only, order, links, empty state), document (title, breadcrumb,
  body, no-text state, 404 for drafts and unknown slugs, open to a signed-in user without roles).
- Shell, phone menu, footer and `NavigationHelper` specs: the new link, its place and its active state.
- `spec/requests/avo_resources_spec.rb`: the Avo resource is admin-only, and creating a document through it saves
  the generated slug and the rich text.
