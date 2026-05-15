# Force-Import Targeted Telegram Messages

**Issue:** vm-0kz (gh-852)
**Depends on:** vm-196 (closed), vm-z20 (in progress)
**Date:** 2026-05-15

## Goal

Allow trusted operators to force-import specific Telegram messages (or short ranges of consecutive messages from one sender) into News drafts, bypassing the normal auto-detection filters. Useful for retroactively capturing messages that:

- Fell below the length / score threshold
- Arrived after the vm-z20 batching window closed
- Were posted by a sender whose `TelegramAuthor` record didn't yet exist

The feature must avoid posting technical control messages into the source group chat. All operator interaction happens via the bot's private DM.

## Constraints

- **Telegram Bot API has no "fetch message by id" method.** The only ways for the bot to obtain a past message's full payload are: (a) the original webhook delivery (already happened, payload not retained), (b) `forwardMessage` / `copyMessage`. `copyMessage` returns only the new message id, so `forwardMessage` is the only viable retrieval path.
- The bot must already be a member of the source chat (otherwise `forwardMessage` returns 403).
- `forwardMessage` requires a destination chat. The destination is the **operator's private chat with the bot** — the operator triggered the import and sees the forwarded copy briefly; no noise leaks into the source group.
- Authorization reuses the existing `TelegramAuthor` whitelist (whitelisted authors may trigger).
- Senders of force-imported messages do **not** have to be whitelisted. If the sender resolves to no usable `User` (no `TelegramAuthor` row, or a row that yields neither a linked user nor a stub via the vm-196 path), the draft falls back to the **operator** as author and the bot DMs a warning. See [Author Resolution](#author-resolution).

## Trigger Interface

Operator sends a private DM to the bot containing a Telegram message link, optionally followed by a range count:

```
https://t.me/c/1234567890/678
https://t.me/c/1234567890/678 +5
https://t.me/channelname/678
https://t.me/channelname/678 +5
```

- `<link>` → import that single message
- `<link> +N` → import that message plus the next `N` sequential `message_id`s (so total `N + 1` messages) as **one merged draft**
- `N` is capped by `telegram_force_import_max_range` FeatureToggle (default `50`). Above the cap, the bot replies with an error.

## Authorization

A DM is treated as a force-import request only when **all** of:

1. `chat.type == "private"` on the incoming webhook payload
2. Sender's `from.id` matches a row in `TelegramAuthor` (the existing author whitelist)
3. Message body matches the link regex

If conditions 1+2 hold but the body doesn't match the link regex, the bot DMs help text (`Не понял ссылку. Пример: …`). Other DMs (chat.type=private, sender not in whitelist) are ignored silently — current behavior for unknown senders.

The `telegram_force_import_enabled` FeatureToggle (default **off**) gates the entire flow. When disabled, a DM matching the link pattern receives "Force-import выключен".

## Filters Bypassed

Force-import unconditionally bypasses all four pipeline filters:

1. `MIN_TEXT_LENGTH = 500`
2. `Telegram::NewsScorer` / score threshold
3. `TelegramAuthor` whitelist of the **original sender** (warns instead of dropping)
4. vm-z20 open-thread merge window (always creates a new draft, never appends to an existing one)

## Range Semantics

For `<link> +N`:

1. Bot calls `forwardMessage` once for each `message_id` from `start_id` through `start_id + N`.
2. 400/404 responses (deleted or otherwise unreachable messages) are silently skipped; the loop continues.
3. After collection, messages are filtered to **only** those whose original sender matches the first successfully forwarded message's original sender. This matches vm-z20's same-author batching semantics.
4. The ack DM reports `imported X/Y (Z skipped)` so the operator knows what made the draft.
5. Total filtered messages = 0 → DM error "Не удалось получить сообщения"; no draft created.

### `forwardMessage` Response Shape

The response from `forwardMessage` is the **new** message created in the destination chat, not a direct echo of the source. Key consequences:

- The response's top-level `from` is the bot (it sent the forward). **Do not** use it for sender filtering.
- Original sender lives under `forward_origin.sender_user` (Bot API 7.0+) with legacy fallback fields `forward_from` (private user) or `forward_sender_name` (when source has hidden forwards) and `forward_from_chat` (when source is a channel post). The service reads original sender id from `forward_origin.sender_user.id` first, then falls back to `forward_from.id`. Messages that resolve to neither (anonymous / hidden forwards) yield a `nil` sender id; they are grouped together by that `nil` and — since no `TelegramAuthor` matches — the draft falls back to operator-as-author with the `no_author` warning DM (see [Author Resolution](#author-resolution)). Dedicated anonymous-admin / `sender_chat` filtering is out of scope for v1.
- Original timestamp lives in `forward_origin.date` (new) or `forward_date` (legacy). Use this for `created_at` and the `telegram_thread_*` columns — not the response's top-level `date` (which is the forward time).
- `text` / `caption` / `entities` / `photo` are preserved at the same top-level keys as a regular message, so `Telegram::MessageParser` works with minimal adaptation — but it currently reads `from.id` for sender, which won't work here. Either extend `MessageParser` with an "extract original sender" path, or duplicate the small bit of payload-reading inside `ForceImportService`. Decide during planning.

## Author Resolution

1. Resolve `TelegramAuthor.find_by(telegram_user_id: sender_id)`.
2. If found:
   - `author.ensure_user!` returns a real or stub `User` (vm-196 path) → use as draft author.
   - `ensure_user!` returns `nil` (whitelisted author with no linked user **and** no linked player — same case `ProcessTelegramWebhookJob` silently drops today) → fall back to step 3.
3. If not found, or step 2 fell back: use the **operator** (the whitelisted DM sender's linked user) as the draft author. Bot DMs a warning: "Автор сообщения не привязан к пользователю — черновик создан под вашим авторством, переназначьте в админке." Operator can re-attribute in the admin News UI.

Rationale: `User.find_or_create_telegram_stub!` requires a `Player`. Force-import with a stranger sender has no player to bind to, so spawning a stub user without one would either require a schema/validation change or a new "anonymous" stub variant — both out of scope for v1. Operator-as-author keeps the path single-line and matches normal moderation behaviour (whoever clicked the button takes responsibility).

## Draft Assembly

The draft is built like vm-z20's threaded draft (single News record with concatenated content), but constructed eagerly from the forwarded payloads instead of accumulating over a time window:

- `title` = first message's plain text, truncated to `MAX_TITLE_LENGTH` (255). If first message has no text (bare photo), use a placeholder ("[медиа]" or similar — pick during implementation; keep consistent with vm-z20 if it sets one).
- `content` = per-message HTML (via existing `Telegram::EntitiesFormatter`), concatenated in `message_id` order. Photos are embedded inline via the existing `embedded_photo_html` helper at the exact position the bare photo or photo-with-caption appeared. Identical to the vm-z20 `append_to_thread` content shape.
- `author` = resolved User (real or stub)
- `status` = `:draft`
- `created_at` = first message's `date`
- `telegram_thread_started_at` = first message's `date`
- `telegram_thread_last_message_at` = last included message's `date`

The thread fields are set even though force-import bypasses the merge window — this keeps the data shape consistent with vm-z20 drafts and lets admin views filter/sort uniformly.

After save:

- `AutolinkPlayersInNewsService.call(news)`
- `NotifyEditorsAboutDraftService.call(news)`
- Bot DMs ack with the new draft's id and import counts (`imported/total`, skipped). No admin URL — the draft is found by id in the admin News list.

If `news.save` fails validation (the assembled content exceeds `News::MAX_CONTENT_LENGTH` — a large range of long messages can blow past the 50k plain-text cap), no draft is created and the bot DMs the `too_long` error instead.

## Components

| File | Responsibility |
|---|---|
| `app/services/telegram/message_link_parser.rb` | Parse operator DM text → `{chat_id, message_id, count}` or `nil`. Handles `t.me/c/<numeric>/<id>` (private, prepend `-100` to recover chat_id) and `t.me/<username>/<id>` (public; resolve username via Bot API `getChat` or store known mapping — see open question). |
| `app/services/telegram/forward_message_service.rb` | Wraps Bot API `forwardMessage`. Mirrors existing `Telegram::RegisterWebhookService` style (HTTPS, no extra gem). Returns parsed payload hash or structured error. |
| `app/services/telegram/bot_dm_service.rb` | Wraps Bot API `sendMessage` for ack/error/warning DMs back to operator. |
| `app/services/telegram/force_import_service.rb` | Orchestrator. Inputs: operator DM payload + parsed link + count. Loops forwards, filters by sender, resolves author, builds draft, sends ack. |
| `app/jobs/process_telegram_webhook_job.rb` | Add early dispatch branch at the top of `#perform`: detect DM-from-whitelisted-author-with-link → call `ForceImportService` and return; otherwise existing flow. |

No new models. No migrations.

## FeatureToggles

| Key | Type | Default | Purpose |
|---|---|---|---|
| `telegram_force_import_enabled` | bool | `false` | Kill switch for the whole flow. |
| `telegram_force_import_max_range` | int | `50` | Maximum `+N` value. |

## Error Surface (operator-facing DMs)

| Case | Bot DM |
|---|---|
| Bad / unrecognized link | "Не понял ссылку. Пример: `https://t.me/c/.../123 +5`" |
| Count exceeds max | "N=… больше лимита 50" |
| Feature disabled | "Force-import выключен" |
| Bot not in source chat (Bot API 403) | "Бот не имеет доступа к чату источнику" |
| All forwards failed (no successful 200s) | "Не удалось получить сообщения" |
| Sender not resolvable to a user (warning, proceeds with operator as author) | "Автор сообщения не привязан к пользователю — черновик создан под вашим авторством, переназначьте в админке." |
| Assembled content exceeds `News::MAX_CONTENT_LENGTH` (draft not created) | "Импортированный текст превышает лимит N символов. Уменьшите диапазон." |
| Success | "Черновик #<id> создан (импортировано X/Y, Z пропущено — другой автор)." |

All operator DMs are Russian per existing project i18n conventions; exact strings finalized during implementation via `config/locales/ru.yml`.

## Out of Scope (v1)

- Idempotency / re-import detection. Two operators force-importing the same link create two drafts. Future enhancement: store `(source_chat_id, source_message_id)` array on News and detect duplicates.
- Admin web UI for triggering imports. v1 is DM-only.
- Multiple separate links in one DM creating multiple drafts. v1: one DM = one draft (a range still counts as one).
- Anonymous-admin / channel-as-sender filtering (`sender_chat` instead of `from`).
- Cancellation / undo of an in-progress force-import.

## Testing Plan

**RSpec coverage (per CLAUDE.md style — `let_it_be` / `let` / nested `context`, no variables in `it` blocks):**

- `spec/services/telegram/message_link_parser_spec.rb` — public link, private (`/c/`) link, with and without `+N`, malformed inputs, count overflow, extra whitespace.
- `spec/services/telegram/forward_message_service_spec.rb` — WebMock stubs for `forwardMessage` API: 200 (returns payload), 400 (missing message), 403 (bot not in chat), generic network error.
- `spec/services/telegram/bot_dm_service_spec.rb` — WebMock stubs for `sendMessage`; verifies request body shape and error swallowing.
- `spec/services/telegram/force_import_service_spec.rb` — happy path (single + range), range with gaps (404 in middle), mixed-sender filter (counts skipped), sender-not-whitelisted stub fallback, bot 403 on source chat, range cap exceeded, feature disabled, all forwards fail.
- `spec/jobs/process_telegram_webhook_job_spec.rb` — dispatch branch: DM + whitelisted sender + link → ForceImportService, normal flow not invoked; non-DM payloads unchanged; DM from non-whitelisted sender ignored.

**Mutation testing (per CLAUDE.md workflow):**
1. `bundle exec evilution run` on each new service + the modified job, with `-j 4`.
2. `bundle exec mutant run -- 'Telegram::ForceImportService' …` etc on each new service class.
3. Fix surviving mutants.
4. Append findings to `.artifacts.local/regular-evilution-feedback.log`.
5. Record scores in PR description (Evilution first, then Mutant).

## Resolved During Planning

1. **Public username links** (`t.me/<username>/<id>`): `forwardMessage` accepts `@<username>` as `from_chat_id`, so no separate id resolution needed. Parser emits either a numeric chat_id (`-100<digits>`) for `/c/` links or a string `@<username>` for username links — both are valid for the Bot API call.
2. **Title fallback for bare-photo first message.** Use the constant `Telegram::ForceImportService::PHOTO_ONLY_TITLE = "[медиа]"` for v1. Operator can edit the draft afterwards.
3. **Stub User without TelegramAuthor row:** falls back to operator-as-author (see [Author Resolution](#author-resolution)). No new stub variant added in v1.
4. **Topic links** (`t.me/c/<chat>/<topic>/<msg>`): parser treats the path as `[chat, ...maybe_topic, msg]` and always takes the **last** numeric segment as `message_id`; ignores topic segment. Topics in supergroups share message_id space, so `forwardMessage` works without the topic id.
