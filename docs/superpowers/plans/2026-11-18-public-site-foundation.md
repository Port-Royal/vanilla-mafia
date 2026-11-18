# Public Site Redesign — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "warm paper" design tokens, the visitor design choice behind the `public_redesign` toggle, and the new
layout shell (top bar, menus, footer, flash, toast), with the old site unchanged for everyone who has not chosen it.

**Architecture:** A plain Ruby `DesignPreference` decides per request (toggle mode × `design` cookie) whether the new
design shows; views ask only the `new_design?` helper. `application.html.erb` captures the page once and renders either
the old shell (moved verbatim into a partial) or the new shell partials under `app/views/layouts/redesign/`. New CSS is
opt-in `vm-*` component classes plus `@theme` tokens; nothing global changes.

**Tech Stack:** Rails 8.1, Tailwind v4 (`tailwindcss-rails`), Stimulus + importmap, RSpec (request/helper specs,
`let_it_be`), Vitest + Stryker for JS, evilution for Ruby.

**Spec:** `docs/superpowers/specs/2026-11-18-public-site-foundation-design.md`

## Global Constraints

- The owner runs every git command. "Commit" steps below mean: stop, list the changed files and the suggested message,
  and hand over. Never commit, push, branch or stash.
- One task = one sub-issue = one PR. Branch name `<gh number>-<slug>` (e.g. `1180-redesign-theme-tokens`), commit body
  `Closes #<n>`.
- URLs, content and i18n keys stay; every new string goes into both `config/locales/ru.yml` and `en.yml`.
- Existing request, system and acceptance specs keep passing. No new JS framework; Stimulus + importmap only.
- No new global CSS rules on `body`, `a`, `h1`…; `.data-table`, `.scroll-wrapper`, `--color-maroon`,
  `--color-row-alt` stay untouched.
- Gold `#d9a21b` is never used for text. Muted text is `#736650`, not `#7d7058`.
- `focus.html.erb` and `overlay.html.erb` layouts are not touched.
- No safe navigation (`&.`), no `and return`; specs use `let_it_be` / `let` and nested `context`, no variables inside
  `it`.
- After each task: `bundle exec rubocop` on changed Ruby, `NO_COVERAGE=1 bundle exec evilution run <file> --jobs 1`
  on changed Ruby (`--spec` when the spec is not path-mapped), Stryker on changed JS; results go to
  `.artifacts.local/regular-evilution-feedback.log` only, never to GitHub.

## Review Focus

1. A `design` cookie with a garbage value (`"beta"`, `""`) — must behave as "no choice yet", never raise. → Task 2.
2. Toggle moved from `opt_in` to `everyone` while a visitor holds `design=old` — they must get the new design, no
   offer, no "back" link. → Task 2 (logic), Task 7 (footer).
3. Toggle switched off after a visitor chose `new` — old design, no offer strip, no "New design" link. → Tasks 2, 3.
4. A signed-in role loses or gains a link when moving from the old shell to the new one (incl. Breakdowns with
   `game_breakdown` off). → Tasks 5, 6 compare against the same conditions as `spec/requests/navigation_spec.rb`.
5. `PATCH /design_preference` with a foreign or missing referer — must land on the site (`root_path`), not leave it.
   → Task 2.

---

## File map

| File | Task | Responsibility |
|------|------|----------------|
| `app/assets/tailwind/application.css` | 1 | tokens, PT Serif import, `vm-*` shell components |
| `app/models/design_preference.rb` | 2 | toggle mode × cookie → which design, offer, switch links |
| `app/models/feature_toggle.rb` | 2 | add `public_redesign` to `KEYS` |
| `app/helpers/design_helper.rb` | 2 | `design_preference`, `new_design?` for views |
| `app/controllers/design_preferences_controller.rb` | 2 | `PATCH /design_preference` sets the cookie |
| `config/routes.rb` | 2 | `resource :design_preference, only: [ :update ]` |
| `spec/support/new_design.rb` | 2 | shared contexts that switch a request to the new or old design |
| `app/views/layouts/_design_offer.html.erb` | 3 | opt-in strip in the old layout |
| `app/views/layouts/application.html.erb` | 3, 4 | strip + "New design" link (3); switch between shells (4) |
| `app/views/layouts/legacy/_shell.html.erb` | 4 | today's body markup, moved verbatim |
| `app/views/layouts/redesign/_shell.html.erb` | 4 | new body: top bar, main, footer, toast |
| `app/views/layouts/redesign/_top_bar.html.erb` | 4, 5, 6 | logo, public nav, locale, sign-in / user menu, phone button |
| `app/views/layouts/redesign/_locale_switcher.html.erb` | 4 | RU/EN in new colours |
| `app/helpers/navigation_helper.rb` | 4, 5 | `nav_active?`, `role_nav_items` |
| `app/views/layouts/redesign/_user_menu.html.erb` | 5 | desktop dropdown |
| `app/javascript/controllers/menu_controller.js` | 5 | per-instance open/close, Escape, outside click |
| `app/views/layouts/redesign/_phone_menu.html.erb` | 6 | phone panel |
| `app/views/layouts/redesign/_footer.html.erb` | 7 | footer + "Back to the old design" |
| `app/views/layouts/redesign/_flash.html.erb` | 8 | flash as panels |
| `app/views/layouts/redesign/_announcement_toast.html.erb` | 8 | restyled toast |

Execution order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8. Tasks 1 and 2 may run in parallel; 3 must land before 4 (4 moves
the markup 3 edits).

---

### Task 1: Theme tokens, fonts and shell components (vm-bpk.1.1 / #1180)

**Files:**
- Modify: `app/assets/tailwind/application.css` (import line, `@theme`, `@layer components`)

**Interfaces:**
- Produces Tailwind colour utilities from tokens: `paper #faf6ec`, `panel #fffdf7`, `line #e6dcc4`,
  `line-soft #f0e8d6`, `ink #2a2418`, `ink-muted #736650`, `label #86681f`, `gold #d9a21b`, `gold-bright #f3c94f`,
  `gold-soft #f3e2b0`, `gold-wash #fbf1d6`, `silver #e3dccb`, `bronze #e9cfae`, `alert-soft #f5ddd5`,
  `alert-ink #8a2a12` (as `--color-<name>`), and `--font-serif: "PT Serif", ui-serif, Georgia, serif`.
- Produces classes: `vm-container` (centred, `max-w-6xl`, `px-4 lg:px-6`), `vm-btn` + `vm-btn--primary` (bg ink,
  text gold-bright, semibold, `rounded-md`, `min-h-9`, `min-h-11` below `lg`) + `vm-btn--ghost` (transparent,
  1 px `#d8cba9` border, ink text), `vm-panel` (bg panel, 1 px line border, `rounded-lg`), `vm-panel--raised`
  (adds one soft shadow), `vm-chrome` (scope class for header/footer/menus: links ink, underline on hover,
  `:focus-visible` 2 px ink outline offset 2 px), `vm-logo` (`filter: invert(.86) sepia(.4)`, `h-8`).

- [ ] **Step 1: Add the font**

Change the Google Fonts import to load Roboto 400/500/700 and PT Serif 700 in one URL
(`family=PT+Serif:wght@700&family=Roboto:wght@400;500;700&display=swap`). CSP already allows https styles/fonts.

- [ ] **Step 2: Add tokens and component classes** listed under Interfaces. Leave every existing rule as is.

- [ ] **Step 3: Verify the build**

Run: `bin/rails tailwindcss:build && grep -o -- "--color-ink-muted\|\.vm-btn--primary\|PT Serif" app/assets/builds/tailwind.css | sort -u`
Expected: build succeeds; all three strings listed (the build is minified onto one line, so count matches, not lines).

Note: Tailwind v4 drops classes no template uses. `vm-*` component classes declared in `@layer components` are kept;
token utilities (e.g. `bg-paper`) appear in the build only once a template uses them — that is expected here.

- [ ] **Step 4: Verify nothing visible changed**

Run: `bundle exec rspec spec/requests`
Expected: all pass. Open `/`, `/news`, `/judge/protocols` locally: unchanged.

- [ ] **Step 5: Commit (owner)** — `feat(redesign): add warm paper tokens, PT Serif and shell components`, `Closes #1180`.

---

### Task 2: Toggle modes and visitor design choice (vm-bpk.1.2 / #1181)

**Files:**
- Create: `app/models/design_preference.rb`, `app/helpers/design_helper.rb`,
  `app/controllers/design_preferences_controller.rb`, `spec/support/new_design.rb`
- Modify: `app/models/feature_toggle.rb` (append `public_redesign` to `KEYS`), `config/routes.rb` (next to
  `resource :locale`)
- Test: `spec/models/design_preference_spec.rb`, `spec/helpers/design_helper_spec.rb`,
  `spec/requests/design_preferences_spec.rb`

**Interfaces:**
- Produces `DesignPreference`:
  - `DesignPreference::TOGGLE_KEY = "public_redesign"`, `COOKIE = :design`, `CHOICES = %w[new old].freeze`
  - `DesignPreference.mode -> Symbol` — `:off` unless `FeatureToggle.enabled?("public_redesign")`; then `:everyone`
    when `FeatureToggle.value_for("public_redesign") == "everyone"`, otherwise `:opt_in`.
  - `DesignPreference.new(mode:, choice:)` — `choice` is the raw cookie value (`String` or `nil`); values outside
    `CHOICES` count as no choice.
  - `#new_design? -> Boolean` — `everyone`, or `opt_in` with choice `"new"`.
  - `#offer? -> Boolean` — `opt_in` and no valid choice.
  - `#switch_to_new? -> Boolean` — `opt_in` and choice `"old"` (shows the "New design" link in the old layout).
  - `#switch_to_old? -> Boolean` — `opt_in` and choice `"new"` (shows "Back to the old design").
- Produces `DesignHelper#design_preference -> DesignPreference` (memoized per request, built from
  `DesignPreference.mode` and `cookies[DesignPreference::COOKIE]`) and `DesignHelper#new_design? -> Boolean`.
- Produces route `design_preference_path` (`PATCH /design_preference`, param `design`).
- Produces in `spec/support/new_design.rb`: `shared_context "with the new design"` (creates
  `feature_toggle key: "public_redesign", enabled: true, value: "everyone"`) and
  `shared_context "with the redesign offered"` (same with `value: "opt_in"`).

- [ ] **Step 1: Write the failing model spec** — `spec/models/design_preference_spec.rb`

```ruby
RSpec.describe DesignPreference do
  describe ".mode" do
    context "when the toggle was never set" do
      it { expect(described_class.mode).to eq(:off) }
    end

    context "when the toggle is disabled" do
      let!(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: false, value: "everyone") }

      it { expect(described_class.mode).to eq(:off) }
    end

    context "when enabled with value everyone" do
      let!(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "everyone") }

      it { expect(described_class.mode).to eq(:everyone) }
    end

    context "when enabled with value opt_in" do
      let!(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "opt_in") }

      it { expect(described_class.mode).to eq(:opt_in) }
    end

    context "when enabled with a blank or unknown value" do
      let!(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "sometimes") }

      it { expect(described_class.mode).to eq(:opt_in) }
    end
  end

  # Full matrix: mode × choice → [new_design?, offer?, switch_to_new?, switch_to_old?]
  {
    [ :off, nil ] => [ false, false, false, false ],
    [ :off, "new" ] => [ false, false, false, false ],
    [ :opt_in, nil ] => [ false, true, false, false ],
    [ :opt_in, "beta" ] => [ false, true, false, false ],
    [ :opt_in, "" ] => [ false, true, false, false ],
    [ :opt_in, "new" ] => [ true, false, false, true ],
    [ :opt_in, "old" ] => [ false, false, true, false ],
    [ :everyone, nil ] => [ true, false, false, false ],
    [ :everyone, "old" ] => [ true, false, false, false ]
  }.each do |(mode, choice), (new_design, offer, to_new, to_old)|
    context "when mode is #{mode} and the cookie is #{choice.inspect}" do
      subject(:preference) { described_class.new(mode: mode, choice: choice) }

      it { expect(preference.new_design?).to be(new_design) }
      it { expect(preference.offer?).to be(offer) }
      it { expect(preference.switch_to_new?).to be(to_new) }
      it { expect(preference.switch_to_old?).to be(to_old) }
    end
  end
end
```

Also add a `FeatureToggle` validation example: `build(:feature_toggle, key: "public_redesign")` is valid.

- [ ] **Step 2: Run, verify it fails** — `bundle exec rspec spec/models/design_preference_spec.rb` → FAIL,
  `uninitialized constant DesignPreference`.

- [ ] **Step 3: Implement `DesignPreference`** (interfaces above) and add the key to `FeatureToggle::KEYS`.

- [ ] **Step 4: Run, verify it passes** — same command → PASS.

- [ ] **Step 5: Write the failing helper spec** — `spec/helpers/design_helper_spec.rb`: with
  `include_context "with the redesign offered"` and `helper.request.cookies[:design] = "new"` →
  `helper.new_design?` is `true`; without the cookie → `false`; `helper.design_preference` returns the same object on
  two calls (`equal`).

- [ ] **Step 6: Implement `DesignHelper`**, run the helper spec → PASS.

- [ ] **Step 7: Write the failing request spec** — `spec/requests/design_preferences_spec.rb`, modelled on
  `spec/requests/locales_spec.rb`:
  - `patch design_preference_path, params: { design: "new" }` → redirects to `root_path`, `cookies[:design] == "new"`
  - same with `"old"` → `"old"`
  - `design: "beta"` → redirects to `root_path`, `cookies[:design]` is `nil`
  - with `HTTP_REFERER` = `hall_path` → redirects to `hall_path`
  - with `HTTP_REFERER` = `"https://evil.example/x"` → redirects to `root_path`
  - works the same when signed in, and does not change the user record

- [ ] **Step 8: Implement `DesignPreferencesController#update` and the route**

Mirror `LocalesController#update`: `return redirect_back(fallback_location: root_path) unless
DesignPreference::CHOICES.include?(params[:design])`; set `cookies[:design] = { value:, expires: 1.year.from_now }`;
`redirect_back(fallback_location: root_path, allow_other_host: false)`.

- [ ] **Step 9: Run all three specs** → PASS. Run evilution on the model, helper and controller
  (`--spec spec/requests/design_preferences_spec.rb` for the controller) → no survivors.

- [ ] **Step 10: Commit (owner)** — `feat(redesign): add public_redesign modes and visitor design choice`,
  `Closes #1181`.

---

### Task 3: Opt-in offer strip and "New design" link (vm-bpk.1.3 / #1182)

**Files:**
- Create: `app/views/layouts/_design_offer.html.erb`
- Modify: `app/views/layouts/application.html.erb` (render the strip as the first child of `<body>`; add the link in
  the desktop sidebar list and the mobile nav list, just before the locale switcher item), `config/locales/ru.yml`,
  `config/locales/en.yml`
- Test: `spec/requests/design_offer_spec.rb`

**Interfaces:**
- Consumes: `design_preference.offer?`, `design_preference.switch_to_new?`, `design_preference_path` (Task 2).
- Produces i18n keys (ru / en):
  - `design.offer.text`: «У сайта новый дизайн — хотите попробовать?» / "There's a new design — want to try it?"
  - `design.offer.try`: «Попробовать» / "Try it"
  - `design.offer.decline`: «Нет, спасибо» / "No thanks"
  - `design.switch_to_new`: «Новый дизайн» / "New design"
  - `design.switch_to_old`: «Вернуться к старому дизайну» / "Back to the old design" (used in Task 7)
- Produces element ids: `design-offer` (strip), `design-switch-to-new` (each link; use a class
  `design-switch-to-new` since the link appears twice).

- [ ] **Step 1: Write the failing request spec** (`get "/news"` in each case):
  - default (no toggle): no `#design-offer`, no `.design-switch-to-new`
  - `include_context "with the redesign offered"`, no cookie: `#design-offer` present with two forms posting
    `design=new` and `design=old` to `design_preference_path`, text from `design.offer.text`
  - offered + `cookies[:design] = "old"`: no `#design-offer`; `.design-switch-to-new` present (form with `design=new`)
  - offered + `cookies[:design] = "new"`: no `#design-offer` (Task 4 will render the new shell here; until then the
    old shell shows with neither strip nor link)
  - `include_context "with the new design"` + `cookies[:design] = "old"`: no strip, no link
  - toggle disabled + `cookies[:design] = "new"`: no strip, no link

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement** the partial (slim full-width strip, `bg-gold-soft text-ink`, text + two `button_to`
  PATCH forms like `_locale_switcher.html.erb`, `form: { class: "inline" }`) and the two `button_to` links in the
  sidebar and mobile nav (sidebar link styling matches its neighbours). Add the i18n keys.

- [ ] **Step 4: Run the new spec and `spec/requests/navigation_spec.rb`** → PASS.

- [ ] **Step 5: Commit (owner)** — `feat(redesign): offer the new design to visitors in opt-in mode`, `Closes #1182`.

---

### Task 4: New layout shell with top bar (vm-bpk.1.4 / #1183)

**Files:**
- Create: `app/views/layouts/legacy/_shell.html.erb`, `app/views/layouts/redesign/_shell.html.erb`,
  `app/views/layouts/redesign/_top_bar.html.erb`, `app/views/layouts/redesign/_locale_switcher.html.erb`,
  `app/helpers/navigation_helper.rb`
- Modify: `app/views/layouts/application.html.erb`
- Test: `spec/requests/redesign/shell_spec.rb`, `spec/helpers/navigation_helper_spec.rb`

**Interfaces:**
- Consumes: `new_design?` (Task 2), `vm-*` classes and tokens (Task 1).
- Produces `NavigationHelper#nav_active?(path) -> Boolean` — `current_page?(path)`, plus `true` for
  `news_index_path` when `request.path` starts with `"#{news_index_path}/"`.
- Produces element ids in the new shell: `site-top-bar` (header), `site-main` (main), and a placeholder container
  `site-user-area` on the right of the bar that Task 5 fills for signed-in users.
- `application.html.erb` structure after this task: `<head>` unchanged; `<body>` class depends on design
  (old: `min-h-screen bg-white font-sans`, new: `min-h-screen bg-paper text-ink font-sans`); body content is
  `render "layouts/legacy/shell", content: yield` or `render "layouts/redesign/shell", content: yield`. The body's
  `data-controller` keeps `time-zone` in both; `menu` stays on `<body>` only for the old shell.

- [ ] **Step 1: Write the failing helper spec** — `nav_active?`: `true` for the current path; `false` for another;
  on `/news/some-slug` → `true` for `news_index_path`, `false` for `hall_path`; on `/newsletter` (not under
  `/news/`) → `false` for `news_index_path`. Set the path with `allow(helper).to receive(:request)` /
  `controller.request.path = …` as the existing helper specs do.

- [ ] **Step 2: Implement `nav_active?`**, run → PASS.

- [ ] **Step 3: Write the failing request spec** `spec/requests/redesign/shell_spec.rb`:
  - default design: `aside#site-sidebar` present, `#site-top-bar` absent (old shell intact)
  - `include_context "with the new design"`: `#site-top-bar` present, `#site-sidebar` and `#site-mobile-header`
    absent; logo `img.vm-logo` links to `root_path`; links to each featured competition, `hall_path`,
    `news_index_path` inside `#site-top-bar nav`; on `get hall_path` the Hall of Fame link has
    `aria-current="page"`; signed out → a `vm-btn--ghost` link to `new_user_session_path`; RU/EN forms posting to
    `locale_path`
  - opted in (`with the redesign offered` + `cookies[:design] = "new"`): new shell renders
  - errors page (`get "/404"`, as `spec/requests/errors_spec.rb` does) renders inside the new shell

- [ ] **Step 4: Run, verify it fails.**

- [ ] **Step 5: Move today's body markup verbatim into `layouts/legacy/_shell.html.erb`** (sidebar, mobile header and
  nav, main with `content`, toast, plus Task 3's strip and links), then make `application.html.erb` switch shells.
  Run `bundle exec rspec spec/requests spec/acceptance` → all old specs still PASS before building the new shell.

- [ ] **Step 6: Build the new shell** — `redesign/_shell`: `div.vm-chrome` header (top bar), `main#site-main.vm-container`
  with `render "devise/shared/flash"` then `content`, toast (old partial until Task 8). `redesign/_top_bar`:
  `header#site-top-bar` paper bg, `border-b border-line`; inside `vm-container` a row: `vm-logo` link; on `lg+` a
  `nav` with the public links in one line (`overflow-x-auto whitespace-nowrap`, no "More" menu), active link
  `font-semibold text-ink` + 2 px gold underline (`shadow-[inset_0_-2px_0_var(--color-gold)]`) +
  `aria-current="page"`, others `text-ink-muted`; spacer; `render "layouts/redesign/locale_switcher"`;
  `#site-user-area` with the sign-in ghost button when signed out. `redesign/_locale_switcher`: same `button_to`
  PATCH logic as the old partial, current locale `font-bold text-ink`, other `text-ink-muted`.

- [ ] **Step 7: Run the spec** → PASS; run `bundle exec rspec` (whole suite) → PASS.

- [ ] **Step 8: Manual check** with `public_redesign` = everyone: `/`, `/news`, a competition, a game, `/hall`,
  `/judge/protocols` (signed in as judge) at 375, 768 and 1280 px. Long competition names scroll inside the nav, never
  the page. Evilution on `navigation_helper.rb`.

- [ ] **Step 9: Commit (owner)** — `feat(redesign): add the new layout shell with top bar`, `Closes #1183`.

---

### Task 5: Signed-in menu in the top bar (vm-bpk.1.5 / #1184)

**Files:**
- Create: `app/views/layouts/redesign/_user_menu.html.erb`, `test/javascript/controllers/menu_controller.test.js`
- Modify: `app/helpers/navigation_helper.rb`, `app/views/layouts/redesign/_top_bar.html.erb`,
  `app/javascript/controllers/menu_controller.js`, `config/locales/ru.yml`, `config/locales/en.yml`
- Test: `spec/helpers/navigation_helper_spec.rb`, `spec/requests/redesign/user_menu_spec.rb`

**Interfaces:**
- Produces `NavigationHelper::NavItem = Data.define(:key, :label, :path)` and
  `NavigationHelper#role_nav_items(user) -> Array<NavItem>` — in this order and under exactly today's conditions
  (`application.html.erb` sidebar): `podcast` (`subscriber? || admin?`), `protocols` (`can_manage_protocols?`),
  `breakdowns` (`can_manage_protocols? && FeatureToggle.enabled?("game_breakdown")`), `help` (`can_view_help?`),
  `manage_news` (`can_manage_news?`), `telegram` (`admin?`), `admin` (`admin?`, path `avo.root_path`),
  `notification_settings` (`can_manage_news?`). Labels from `t("nav.<key>")`. Sign out is not an item (it is a
  `button_to` DELETE).
- Produces i18n key `nav.menu`: «Меню» / "Menu".
- Produces `menu_controller.js` API (backward compatible with the old shell):
  targets `nav`, `button`; actions `toggle()`, `close()`, `closeOnOutside(event)`. Wire per instance with
  `data-action="click->menu#toggle"` on the button and
  `click@window->menu#closeOnOutside keydown.esc@window->menu#close` on the controller element.
- Produces element id `site-user-menu` (the dropdown panel, `vm-panel vm-panel--raised`, `hidden` by default) and
  `site-user-menu-button`.

- [ ] **Step 1: Write failing Vitest tests** (style of `slug_suggest_controller.test.js`):
  - `toggle` shows the nav and sets `aria-expanded="true"`; a second `toggle` hides it and sets `"false"`
  - `Escape` on `window` closes an open menu and sets `aria-expanded="false"`
  - a click outside the controller element closes it; a click inside the nav does not
  - two controller instances on one page: toggling one leaves the other hidden

- [ ] **Step 2: Run** `npm test -- menu_controller` → FAIL (no `close`, no outside handling).

- [ ] **Step 3: Implement** `close()` (add `hidden`, `aria-expanded="false"`) and `closeOnOutside(event)` (close
  unless `this.element.contains(event.target)`). `toggle()` unchanged.

- [ ] **Step 4: Run** `npm test` → PASS; `npx stryker run --mutate app/javascript/controllers/menu_controller.js` →
  no survivors.

- [ ] **Step 5: Write the failing helper spec** for `role_nav_items` — one context per user kind (`create(:user)`,
  `:subscriber`, `:judge`, `:editor`, `:admin`), each asserting the exact ordered `map(&:key)`; judge with
  `game_breakdown` on and off.

- [ ] **Step 6: Implement `role_nav_items`**, run → PASS; evilution on `navigation_helper.rb` → no survivors.

- [ ] **Step 7: Write the failing request spec** `spec/requests/redesign/user_menu_spec.rb` with
  `include_context "with the new design"`: for each user kind, `#site-user-menu` contains exactly the hrefs of
  `role_nav_items(user)` plus a sign-out form to `destroy_user_session_path`; signed out → no `#site-user-menu`.
  Cross-check: the same user kinds in the old shell (`spec/requests/navigation_spec.rb`) show the same hrefs.

- [ ] **Step 8: Implement `_user_menu`** inside `#site-user-area` (button with `t("nav.menu")` and a chevron,
  `aria-controls="site-user-menu"`, `aria-expanded="false"`; panel right-aligned under the button, links as a
  vertical list, sign out last after a `border-t border-line`). Only on `lg+`.

- [ ] **Step 9: Run** the request spec and the whole suite → PASS.

- [ ] **Step 10: Commit (owner)** — `feat(redesign): add the signed-in menu to the top bar`, `Closes #1184`.

---

### Task 6: Phone menu (vm-bpk.1.6 / #1185)

**Files:**
- Create: `app/views/layouts/redesign/_phone_menu.html.erb`
- Modify: `app/views/layouts/redesign/_top_bar.html.erb`
- Test: `spec/requests/redesign/phone_menu_spec.rb`

**Interfaces:**
- Consumes: `role_nav_items`, `menu_controller.js` (Task 5), `nav_active?` (Task 4).
- Produces element ids `site-phone-menu-button` (below `lg` only, 44 px tap target, `aria-controls="site-phone-menu"`)
  and `site-phone-menu` (full-width panel under the bar, `hidden` by default, own `menu` controller instance).

- [ ] **Step 1: Write the failing request spec** with `include_context "with the new design"`: for each user kind,
  `#site-phone-menu` lists, in order, the featured competitions, `hall_path`, `news_index_path`, then the
  `role_nav_items` hrefs, then sign out (signed in) or `new_user_session_path` (signed out), then the RU/EN forms;
  the button has `aria-expanded="false"`.

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement** the button (menu icon, `lg:hidden`) and `_phone_menu` (sections separated by
  `border-t border-line`, links `min-h-11`, active link per `nav_active?`), wrapped in its own
  `data-controller="menu"` element.

- [ ] **Step 4: Run** → PASS; manual check at 375 px: opens, closes on Escape and outside tap, desktop dropdown
  unaffected.

- [ ] **Step 5: Commit (owner)** — `feat(redesign): add the phone menu to the new shell`, `Closes #1185`.

---

### Task 7: Footer (vm-bpk.1.7 / #1186)

**Files:**
- Create: `app/views/layouts/redesign/_footer.html.erb`
- Modify: `app/views/layouts/redesign/_shell.html.erb`, `config/locales/ru.yml`, `config/locales/en.yml`
- Test: `spec/requests/redesign/footer_spec.rb`

**Interfaces:**
- Consumes: `design_preference.switch_to_old?`, `design_preference_path` (Task 2), `design.switch_to_old` (Task 3).
- Produces i18n key `footer.copyright`: «© %{year} Vanilla Mafia» / "© %{year} Vanilla Mafia".
- Produces element ids `site-footer`, `design-switch-to-old`.

- [ ] **Step 1: Write the failing request spec:**
  - `with the new design`: `footer#site-footer` shows `t("footer.copyright", year: Date.current.year)` and links to
    `hall_path` and `news_index_path`; no `#design-switch-to-old`
  - `with the new design` + `cookies[:design] = "old"`: still no `#design-switch-to-old` (Review Focus 2)
  - `with the redesign offered` + `cookies[:design] = "new"`: `#design-switch-to-old` is a form posting `design=old`
    to `design_preference_path`
  - default design: no `#site-footer`

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement** — `border-t border-line`, `text-ink-muted text-xs` (13 px), inside `vm-container`,
  `vm-chrome`; render it after `main` in the new shell.

- [ ] **Step 4: Run** → PASS.

- [ ] **Step 5: Commit (owner)** — `feat(redesign): add the footer to the new shell`, `Closes #1186`.

---

### Task 8: Flash messages and announcement toast (vm-bpk.1.8 / #1187)

**Files:**
- Create: `app/views/layouts/redesign/_flash.html.erb`, `app/views/layouts/redesign/_announcement_toast.html.erb`
- Modify: `app/views/layouts/redesign/_shell.html.erb`
- Test: `spec/requests/redesign/notices_spec.rb`

**Interfaces:**
- Consumes: `vm-panel`, `vm-panel--raised`, tokens (Task 1).
- Produces: new-shell flash (`div.vm-panel` per message; `alert` → `bg-alert-soft text-alert-ink border-alert-ink/20`,
  others → panel with ink text; blank messages skipped as today) and new-shell toast (same `data-controller`,
  `data-announcement-dismiss-url-value`, `data-action`, `data-announcement-ids`, title `home.whats_new.toast_title`
  in `font-semibold text-ink`; container `fixed bottom-4 inset-x-4 lg:left-auto lg:right-4 lg:max-w-sm`; close
  button `min-h-11 min-w-11` below `lg`). The old partials (`devise/shared/_flash`, `layouts/_announcement_toast`)
  stay unchanged for the old shell.

- [ ] **Step 1: Write the failing request spec** with `include_context "with the new design"` and
  `toast_whats_new` enabled, signed in, one announcement (as `spec/requests/announcement_toast_spec.rb`):
  toast renders inside `.vm-panel--raised` with the message, the dismiss action and the ids; contains no `maroon`
  class. Flash: after a failed sign-in (`post user_session_path` with a wrong password, then follow the render) the
  alert renders with `bg-alert-soft`.

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement** both partials and render them from `redesign/_shell` in place of the old ones.

- [ ] **Step 4: Run** this spec, `spec/requests/announcement_toast_spec.rb`, `spec/requests/announcement_dismissals_spec.rb`
  and the whole suite → PASS. Manual check at 375 px: toast spans the width minus 16 px gutters and dismisses.

- [ ] **Step 5: Commit (owner)** — `feat(redesign): restyle flash and toast in the new shell`, `Closes #1187`.

After Task 8 lands, close vm-bpk.1 / #1170.
