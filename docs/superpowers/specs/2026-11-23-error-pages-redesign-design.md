# Public site redesign — error pages

- Epic: vm-bpk / gh-1126 — Redesign of the public site
- This task: vm-bpk.9 / gh-1178
- Builds on: the foundation spec and the page designs merged so far (home, game, competition, player, news); shared
  components `vm-btn`, `vm-btn--primary`, tokens `ink`, `ink-muted`, `gold`, `gold-line`
- Status: autonomous run — no mockup round with the owner; decisions listed at the end for review

## The current page

`config.exceptions_app = routes`; `/404`, `/422` and `/500` route to `ErrorsController#show`
(`ActionController::Base`, `application` layout, no `SetPreferences`). One template, `errors/show`: the code in a huge
light grey number, the title (`errors.<code>.title`), the message (`errors.<code>.message`), a dark «На главную»
button (`errors.back_home`), and `noindex, nofollow`. Any code outside 404/422/500 falls back to 500.

- States: three codes, all the same shape. No data, no long names, no lists, no empty state.
- Judges and admins see exactly the same content; only the shell differs (the user menu).
- Since the foundation task, the error page already renders inside the new shell when `new_design?` (covered by
  `spec/requests/redesign/shell_spec.rb`); only the content is still in the old grey/neutral style.
- Missing records (`ActiveRecord::RecordNotFound`) and unknown URLs land on the same 404.

Static files in `public/`: `400.html` and `406-unsupported-browser.html`, the stock Rails 8 pages (English, Rails
logo-style SVG, dark-mode aware). There is no `404.html`, `422.html` or `500.html`.

- `406-unsupported-browser.html` is rendered by `allow_browser` (`ApplicationController`) with `layout: false`.
- `400.html` is never served by the app: a 400 goes to `exceptions_app` → `/400` has no route → Rails returns an
  empty 400 body. It is reachable only as the static URL `/400.html`.

## Design

`ErrorsController#show` renders `errors/redesign/show` when `helpers.new_design?`; otherwise `errors/show` exactly as
today. Same status codes, same i18n keys, no new strings.

A single centred column (max ~576 px), generous vertical space (64 px phone / 96 px desktop), no panel:

- the code as a big serif number (72 px phone / 112 px desktop) in `gold-line` — decorative, `aria-hidden`; the title
  says the same thing in words (gold-family text is allowed here only because nobody needs to read it);
- a short 2 px `gold` rule under it;
- the title `h1`, serif, the standard page-title size (22 / 28 px), `ink`;
- the message, 15 px, `ink-muted`;
- «На главную» as the primary button (`vm-btn vm-btn--primary`: ink with gold-bright text).

The top bar of the shell already gives the way to the main sections, so the page adds no extra links.

## Static pages in `public/`

Left unchanged. They are served without the app (no layout, no cookie, no toggle), so a restyle would show the new
look to everyone while the toggle is off, against the transition rule. Restyling them in plain HTML/CSS belongs to the
cleanup task (vm-bpk.10), once the new design is the only design.

## Testing

- `spec/requests/redesign/errors_spec.rb`: toggle off → old page; toggle on → `/404`, `/422`, `/500`, a code in the
  query string, an unknown URL, a missing record and a signed-in admin each render the new page with the right status,
  code, title, message, home button and robots meta.
- `spec/requests/errors_spec.rb` (old design) and `spec/requests/redesign/shell_spec.rb` keep passing.
- Evilution on `app/controllers/errors_controller.rb`.
