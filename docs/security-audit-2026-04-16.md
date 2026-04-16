# Security Audit Report — 2026-04-16

Beads: vm-55 | GH: #710

## Tools Used

- **Brakeman 8.0.4**: 0 warnings (44 controllers, 27 models, 64 templates)
- **bundle-audit**: 0 vulnerabilities (advisory DB updated 2026-03-30)
- **npm audit**: N/A (no lockfile — app uses importmaps)
- **Manual review**: all 12 audit areas from the issue checklist

---

## Findings by Severity

### HIGH

#### H1: No rate limiting

No `rack-attack` gem installed. No throttling on any endpoint.

**Unprotected endpoints:** login, registration, password reset, all form submissions.

- **File**: `Gemfile` (missing), no `config/initializers/rack_attack.rb`
- **Fix**: Add `rack-attack` gem, configure throttles for login (5/min per IP), password reset (3/hour per email), and a global per-IP limit.

#### H2: No account lockout (Devise `:lockable` not enabled)

Zero protection against brute-force credential stuffing. Combined with H1 this is the most critical gap.

- **File**: `app/models/user.rb:2` — `:lockable` absent from devise modules
- **File**: `config/initializers/devise.rb:197-220` — all lockout config commented out
- **Fix**: Add `:lockable` to User model, uncomment and configure `lock_strategy: :failed_attempts`, `maximum_attempts: 5`, `unlock_strategy: :both`, `unlock_in: 15.minutes`. Add migration for `failed_attempts`, `unlock_token`, `locked_at` columns.

#### H3: No Content-Security-Policy header

Entire CSP configuration commented out. No defense-in-depth against XSS or inline script injection.

- **File**: `config/initializers/content_security_policy.rb` — all lines commented
- **Fix**: Enable a basic CSP. Start with report-only mode, then enforce.

#### H4: No file upload validation on 5 of 6 models

`PlayerClaim` is the only model with content type and file size validation. The other 5 models with ActiveStorage attachments have none.

| Model | Attachment | Content type validation | Size limit |
|-------|-----------|------------------------|------------|
| Episode | audio, image | None | None |
| Podcast | cover | None | None |
| Player | photo | None | None |
| News | photos | None | None |
| Award | icon | None | None |
| PlayerClaim | selfie, documents | Yes | 10 MB |

- **Fix**: Add `validates` with content type allowlists and size limits to each model. PlayerClaim is a good reference implementation.

#### H5: Unauthenticated ActionCable — game protocol data exposed

`ApplicationCable::Connection` performs no authentication. `GameProtocolChannel#subscribed` checks only that the game ID exists, not user identity or authorization. Any anonymous WebSocket client can subscribe and receive real-time protocol updates (roles, seats).

- **File**: `app/channels/application_cable/connection.rb` (empty)
- **File**: `app/channels/game_protocol_channel.rb:3`
- **Fix**: Add `identified_by :current_user` with Warden session auth in Connection. Add authorization check in the channel.

### MEDIUM

#### M1: No session timeout

`:timeoutable` not in User devise modules. Stolen sessions last indefinitely.

- **File**: `config/initializers/devise.rb:194`, `app/models/user.rb:2`
- **Fix**: Add `:timeoutable`, set `config.timeout_in = 30.minutes`.

#### M2: Paranoid mode disabled — user enumeration possible

Password reset and login flows reveal whether an email is registered.

- **File**: `config/initializers/devise.rb:93`
- **Fix**: Uncomment `config.paranoid = true`.

#### M3: No email/password change notifications

Account takeover produces no alert to the legitimate user.

- **File**: `config/initializers/devise.rb:132-135`
- **Fix**: Set `send_email_changed_notification = true` and `send_password_change_notification = true`.

#### M4: Host header validation disabled

`config.hosts` commented out. Enables host header injection that can poison password reset links and caches.

- **File**: `config/environments/production.rb:79-85`
- **Fix**: Uncomment and set `config.hosts = ["cnxmafia.org", /.*\.cnxmafia\.org/]`.

#### M5: No Permissions-Policy header

Browser features (camera, microphone, geolocation) not restricted.

- **Fix**: Create `config/initializers/permissions_policy.rb` with restrictive defaults.

#### M6: Sentry sends PII without scrubbing

`send_default_pii = true` in production sends request headers, IPs, and cookies to Sentry with no `before_send` filter.

- **File**: `config/initializers/sentry.rb:9`
- **Fix**: Add a `before_send` callback to strip sensitive headers, or set `send_default_pii = false` and selectively include what's needed.

### LOW

#### L1: Remember-me cookie options not explicitly hardened

- **File**: `config/initializers/devise.rb:180`
- **Fix**: Set `rememberable_options = { secure: true, httponly: true, same_site: :lax }`.

#### L2: Preference cookies lack security flags

`locale` and `datetime_format` cookies set without `httponly` or `secure`.

- **Files**: `app/controllers/locales_controller.rb:6`, `app/controllers/datetime_formats_controller.rb:6`

#### L3: PlaybackPositionsController uses raw params

Direct `params[:position_seconds]` and `params[:playback_speed]` assignment without strong params wrapper. Mitigated by ActiveRecord type casting.

- **File**: `app/controllers/podcast/playback_positions_controller.rb:10-11`

#### L4: Raw SQL interpolation in Competition

Uses `connection.quote(id)` for own primary key in recursive CTE. Functionally safe but a bind parameter would be cleaner.

- **File**: `app/models/competition.rb:54-57`

#### L5: News loaded without includes in HomeController

`News.visible.recent.limit(3)` without `includes` — potential N+1 for up to 3 records.

- **File**: `app/controllers/home_controller.rb:22`

---

## Positive Findings

These areas are well-handled:

1. **Brakeman clean**: zero warnings across the entire codebase
2. **No dependency vulnerabilities**: bundle-audit reports zero CVEs
3. **Strong password policy**: 10+ chars, 3/4 character classes, common password blocklist
4. **Pundit authorization throughout**: admin/editor actions gated properly
5. **Defense-in-depth routing**: route-level `authenticate` constraints plus controller-level `before_action`
6. **CSRF protection correct**: only skipped on token-authenticated podcast endpoints
7. **Telegram webhook secured**: `ActiveSupport::SecurityUtils.secure_compare` on shared secret
8. **Strong parameters everywhere**: no `permit!`, no dangerous attributes permitted
9. **No SQL injection**: all queries parameterized, Avo search uses `?` placeholders
10. **No XSS**: no `raw` in views, single `html_safe` is SDK-generated (Sentry)
11. **SSL enforced**: `force_ssl = true`, `assume_ssl = true` in production
12. **Comprehensive param filtering**: passwords, tokens, keys, secrets all filtered from logs
13. **All FK columns indexed** with database-level constraints
14. **Custom error pages**: `ErrorsController` renders only whitelisted status codes
15. **Secrets properly managed**: all credentials via ENV or Rails encrypted credentials
16. **ActionText sanitization**: rich text content sanitized by default

---

## Checklist Summary

| Area | Status |
|------|--------|
| Authentication & session management | Needs lockout, timeout, paranoid mode |
| Authorization checks | Good — Pundit + route constraints |
| Input validation & sanitization | Good — strong params, no SQL injection, no XSS |
| CSRF protection | Good — justified exceptions only |
| File upload security | Needs content type + size validation on 5 models |
| Mass assignment protection | Good — modern strong params throughout |
| Dependency vulnerabilities | Clean |
| Secrets management | Good |
| Rate limiting | Missing entirely |
| HTTP security headers | Needs CSP, Permissions-Policy, host validation |
| Information disclosure | Good — minor Sentry PII concern |
| Database security | Good — all FKs indexed, proper pooling |
