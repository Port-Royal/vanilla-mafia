# Telegram Force-Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow whitelisted Telegram authors to retroactively force-import a single Telegram message (or short consecutive range from one sender) into a News draft via private DM to the bot, bypassing every automatic filter.

**Architecture:** Operator DMs the bot a `t.me/...` message link with an optional `+N` range count. `ProcessTelegramWebhookJob` detects this shape (private chat + whitelisted sender + link regex match) and hands off to `Telegram::ForceImportService`. The service uses Bot API `forwardMessage` to retrieve each target message's payload (the only post-hoc retrieval channel Telegram offers), filters by original sender, builds one consolidated News draft with the same content/photo shape as vm-z20 threads, and DMs the operator with success/error feedback.

**Tech Stack:** Rails 8.1.2, Ruby 4.0.1, RSpec, Net::HTTP (no extra gems — matches existing `Telegram::RegisterWebhookService`), `FeatureToggle` model for kill switch + range cap.

**Spec:** `docs/superpowers/specs/2026-05-15-telegram-force-import-design.md`

**Beads:** vm-0kz · GitHub #852

---

## File Structure

**Create:**
- `app/services/telegram/message_link_parser.rb` — pure parser: text → `{source_chat:, message_id:, count:}` or `nil`
- `app/services/telegram/forward_message_service.rb` — `forwardMessage` Bot API wrapper
- `app/services/telegram/bot_dm_service.rb` — `sendMessage` Bot API wrapper for ack/error DMs
- `app/services/telegram/force_import_service.rb` — orchestrator
- `spec/services/telegram/message_link_parser_spec.rb`
- `spec/services/telegram/forward_message_service_spec.rb`
- `spec/services/telegram/bot_dm_service_spec.rb`
- `spec/services/telegram/force_import_service_spec.rb`

**Modify:**
- `app/models/feature_toggle.rb` — add two keys to `KEYS`
- `app/jobs/process_telegram_webhook_job.rb` — add early dispatch branch at top of `#perform`
- `spec/jobs/process_telegram_webhook_job_spec.rb` — add dispatch context
- `config/locales/ru.yml` — add `telegram.force_import.*` strings

---

## Task 1: Add FeatureToggle keys

**Files:**
- Modify: `app/models/feature_toggle.rb:2-24`
- Test: `spec/models/feature_toggle_spec.rb` (only if it asserts on the KEYS list — extend if so; otherwise no new test)

- [ ] **Step 1: Inspect the existing spec to see whether KEYS membership is asserted**

Run: `grep -n "KEYS\|inclusion" spec/models/feature_toggle_spec.rb`

If a test asserts on specific keys, update it accordingly in Step 3.

- [ ] **Step 2: Add the two new keys**

Edit `app/models/feature_toggle.rb`, inside the `KEYS` array, after `telegram_thread_window_strategy`:

```ruby
KEYS = %w[
  require_approval
  home_hero
  home_running_tournaments
  home_recently_finished
  home_recent_games
  home_latest_news
  home_hall_of_fame
  home_stats
  home_documents
  home_whats_new
  toast_whats_new
  news_classic_pagination
  news_infinite_scroll
  news_per_page
  news_max_article_length
  news_score_keywords
  news_score_threshold
  news_autolink_players
  telegram_thread_window
  telegram_thread_window_seconds
  telegram_thread_window_strategy
  telegram_force_import_enabled
  telegram_force_import_max_range
].freeze
```

- [ ] **Step 3: Update FeatureToggle spec if it asserted specific keys**

If Step 1 found such an assertion, extend it. Otherwise skip.

- [ ] **Step 4: Run the FeatureToggle spec**

Run: `bundle exec rspec spec/models/feature_toggle_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/feature_toggle.rb spec/models/feature_toggle_spec.rb
git commit -m "feat(feature_toggle): add force_import keys

Keys for vm-0kz force-import kill switch and range cap."
```

---

## Task 2: `Telegram::MessageLinkParser`

Pure parser. No I/O. Extracts `(source_chat, message_id, count)` from operator DM text.

**Files:**
- Create: `app/services/telegram/message_link_parser.rb`
- Test: `spec/services/telegram/message_link_parser_spec.rb`

- [ ] **Step 1: Write the failing tests**

Create `spec/services/telegram/message_link_parser_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Telegram::MessageLinkParser do
  describe ".call" do
    context "with a private supergroup link" do
      it "parses chat_id with the -100 prefix" do
        result = described_class.call("https://t.me/c/1234567890/678")
        expect(result.source_chat).to eq(-1001234567890)
      end

      it "parses message_id" do
        result = described_class.call("https://t.me/c/1234567890/678")
        expect(result.message_id).to eq(678)
      end

      it "defaults count to 0 when no suffix" do
        result = described_class.call("https://t.me/c/1234567890/678")
        expect(result.count).to eq(0)
      end
    end

    context "with a private supergroup topic link" do
      it "uses the last numeric segment as message_id and ignores the topic id" do
        result = described_class.call("https://t.me/c/1234567890/45/678")
        expect(result.message_id).to eq(678)
        expect(result.source_chat).to eq(-1001234567890)
      end
    end

    context "with a public username link" do
      it "returns @username as source_chat" do
        result = described_class.call("https://t.me/channelname/678")
        expect(result.source_chat).to eq("@channelname")
      end

      it "parses message_id" do
        result = described_class.call("https://t.me/channelname/678")
        expect(result.message_id).to eq(678)
      end
    end

    context "with a range suffix" do
      it "parses +N as count" do
        result = described_class.call("https://t.me/c/1234567890/678 +5")
        expect(result.count).to eq(5)
      end

      it "tolerates extra whitespace" do
        result = described_class.call("  https://t.me/c/1234567890/678   +12  ")
        expect(result.count).to eq(12)
        expect(result.message_id).to eq(678)
      end
    end

    context "with malformed input" do
      it "returns nil for blank text" do
        expect(described_class.call("")).to be_nil
      end

      it "returns nil for non-telegram URLs" do
        expect(described_class.call("https://example.com/foo/123")).to be_nil
      end

      it "returns nil for telegram link without numeric message id" do
        expect(described_class.call("https://t.me/channelname/abc")).to be_nil
      end

      it "returns nil for /c/ link without message id" do
        expect(described_class.call("https://t.me/c/1234567890")).to be_nil
      end

      it "returns nil for negative or zero count" do
        expect(described_class.call("https://t.me/c/1234567890/678 +0")).to be_nil
        expect(described_class.call("https://t.me/c/1234567890/678 +-1")).to be_nil
      end

      it "returns nil for non-string input" do
        expect(described_class.call(nil)).to be_nil
        expect(described_class.call(12345)).to be_nil
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/telegram/message_link_parser_spec.rb`
Expected: FAIL — "uninitialized constant Telegram::MessageLinkParser"

- [ ] **Step 3: Implement the parser**

Create `app/services/telegram/message_link_parser.rb`:

```ruby
module Telegram
  class MessageLinkParser
    Result = Data.define(:source_chat, :message_id, :count)

    PRIVATE_LINK = %r{\Ahttps://t\.me/c/(\d+)/(?:\d+/)?(\d+)\z}
    PUBLIC_LINK  = %r{\Ahttps://t\.me/([A-Za-z][A-Za-z0-9_]{3,31})/(\d+)\z}
    SUFFIX       = /\A\s*(.+?)(?:\s+\+(\d+))?\s*\z/

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      return nil unless @text.is_a?(String)

      match = SUFFIX.match(@text)
      return nil if match.nil?

      link = match[1]
      count = parse_count(match[2])
      return nil if count.nil?

      parse_link(link, count)
    end

    private

    def parse_count(raw)
      return 0 if raw.nil?

      n = Integer(raw, 10)
      return nil if n <= 0

      n
    rescue ArgumentError
      nil
    end

    def parse_link(link, count)
      if (m = PRIVATE_LINK.match(link))
        Result.new(source_chat: -("100#{m[1]}".to_i), message_id: m[2].to_i, count: count)
      elsif (m = PUBLIC_LINK.match(link))
        Result.new(source_chat: "@#{m[1]}", message_id: m[2].to_i, count: count)
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/telegram/message_link_parser_spec.rb`
Expected: PASS, all examples.

- [ ] **Step 5: Lint**

Run: `bundle exec rubocop app/services/telegram/message_link_parser.rb spec/services/telegram/message_link_parser_spec.rb`
Fix any offences. Re-run until clean.

- [ ] **Step 6: Commit**

```bash
git add app/services/telegram/message_link_parser.rb spec/services/telegram/message_link_parser_spec.rb
git commit -m "feat(telegram): add MessageLinkParser for force-import (vm-0kz)

Parses t.me/c/<id>/<msg>, t.me/c/<id>/<topic>/<msg>, t.me/<username>/<msg>
forms with optional ' +N' range suffix. Returns Data struct or nil."
```

---

## Task 3: `Telegram::ForwardMessageService`

Wraps Bot API `forwardMessage`. Same `Net::HTTP.post_form` style as `Telegram::RegisterWebhookService`. Spec stubs `Net::HTTP.post_form` directly (no WebMock in project per Gemfile check).

**Files:**
- Create: `app/services/telegram/forward_message_service.rb`
- Test: `spec/services/telegram/forward_message_service_spec.rb`

- [ ] **Step 1: Write the failing tests**

Create `spec/services/telegram/forward_message_service_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Telegram::ForwardMessageService do
  let(:bot_token) { "123456:ABC-DEF" }
  let(:from_chat_id) { -1001234567890 }
  let(:message_id) { 678 }
  let(:to_chat_id) { 555 }

  around do |example|
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  describe ".call" do
    context "when the API returns ok=true" do
      let(:response_body) do
        {
          "ok" => true,
          "result" => {
            "message_id" => 999,
            "text" => "hello world",
            "from" => { "id" => 42, "is_bot" => true },
            "forward_origin" => {
              "type" => "user",
              "sender_user" => { "id" => 12345, "first_name" => "Alex" },
              "date" => 1710000000
            }
          }
        }
      end
      let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

      before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

      it "returns success" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be true
      end

      it "returns the forwarded message hash" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.message).to eq(response_body["result"])
      end

      it "calls the correct API endpoint with correct params" do
        described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(Net::HTTP).to have_received(:post_form).with(
          URI("https://api.telegram.org/bot#{bot_token}/forwardMessage"),
          {
            "chat_id" => to_chat_id.to_s,
            "from_chat_id" => from_chat_id.to_s,
            "message_id" => message_id.to_s,
            "disable_notification" => "true"
          }
        )
      end

      it "accepts @username as from_chat_id" do
        described_class.call(from_chat_id: "@channelname", message_id: message_id, to_chat_id: to_chat_id)
        expect(Net::HTTP).to have_received(:post_form).with(
          anything,
          hash_including("from_chat_id" => "@channelname")
        )
      end
    end

    context "when the API returns ok=false with 400" do
      let(:response_body) { { "ok" => false, "error_code" => 400, "description" => "Bad Request: message to forward not found" } }
      let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

      before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

      it "returns failure" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
      end

      it "exposes the error_code" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.error_code).to eq(400)
      end

      it "exposes the description" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.description).to eq("Bad Request: message to forward not found")
      end
    end

    context "when the API returns 403" do
      let(:response_body) { { "ok" => false, "error_code" => 403, "description" => "Forbidden: bot is not a member" } }
      let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

      before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

      it "returns failure with error_code 403" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
        expect(result.error_code).to eq(403)
      end
    end

    context "when bot_token is blank" do
      let(:bot_token) { nil }

      it "returns failure with a missing-token description" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
        expect(result.description).to include("bot_token")
      end
    end

    context "when a network error occurs" do
      before { allow(Net::HTTP).to receive(:post_form).and_raise(Net::ReadTimeout) }

      it "returns failure with the error class in description" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
        expect(result.description).to include("Net::ReadTimeout")
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/telegram/forward_message_service_spec.rb`
Expected: FAIL — uninitialized constant.

- [ ] **Step 3: Implement the service**

Create `app/services/telegram/forward_message_service.rb`:

```ruby
require "net/http"
require "json"

module Telegram
  class ForwardMessageService
    Result = Data.define(:success, :message, :error_code, :description)

    BASE_URL = "https://api.telegram.org".freeze

    def self.call(from_chat_id:, message_id:, to_chat_id:)
      new.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
    end

    def call(from_chat_id:, message_id:, to_chat_id:)
      token = bot_token
      return error("Missing required config: bot_token") if token.blank?

      params = {
        "chat_id" => to_chat_id.to_s,
        "from_chat_id" => from_chat_id.to_s,
        "message_id" => message_id.to_s,
        "disable_notification" => "true"
      }

      uri = URI("#{BASE_URL}/bot#{token}/forwardMessage")
      response = Net::HTTP.post_form(uri, params)
      data = JSON.parse(response.body)

      if data["ok"]
        Result.new(success: true, message: data["result"], error_code: nil, description: nil)
      else
        Result.new(success: false, message: nil, error_code: data["error_code"], description: data["description"])
      end
    rescue JSON::ParserError,
           SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      error("#{e.class}: #{e.message}")
    end

    private

    def bot_token
      Rails.application.config.x.telegram.bot_token
    end

    def error(description)
      Result.new(success: false, message: nil, error_code: nil, description: description)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/telegram/forward_message_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `bundle exec rubocop app/services/telegram/forward_message_service.rb spec/services/telegram/forward_message_service_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/services/telegram/forward_message_service.rb spec/services/telegram/forward_message_service_spec.rb
git commit -m "feat(telegram): add ForwardMessageService for force-import (vm-0kz)

Bot API forwardMessage wrapper. Accepts numeric or @username from_chat_id,
returns Result struct with full message payload on success, error_code on
failure. Silent forwards (disable_notification: true)."
```

---

## Task 4: `Telegram::BotDmService`

Sends a plain-text reply DM to the operator. Best-effort: failures are logged but never raise (we don't want to abort a successful import because the ack DM failed).

**Files:**
- Create: `app/services/telegram/bot_dm_service.rb`
- Test: `spec/services/telegram/bot_dm_service_spec.rb`

- [ ] **Step 1: Write the failing tests**

Create `spec/services/telegram/bot_dm_service_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Telegram::BotDmService do
  let(:bot_token) { "123456:ABC-DEF" }
  let(:chat_id) { 555 }
  let(:text) { "Hello operator" }

  around do |example|
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  describe ".call" do
    let(:response_body) { { "ok" => true, "result" => { "message_id" => 1 } } }
    let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

    before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

    it "posts to sendMessage with chat_id and text" do
      described_class.call(chat_id: chat_id, text: text)
      expect(Net::HTTP).to have_received(:post_form).with(
        URI("https://api.telegram.org/bot#{bot_token}/sendMessage"),
        { "chat_id" => chat_id.to_s, "text" => text, "disable_web_page_preview" => "true" }
      )
    end

    it "returns truthy on API success" do
      expect(described_class.call(chat_id: chat_id, text: text)).to be_truthy
    end

    context "when the API returns ok=false" do
      let(:response_body) { { "ok" => false, "description" => "chat not found" } }

      it "logs a warning and returns false" do
        allow(Rails.logger).to receive(:warn)
        result = described_class.call(chat_id: chat_id, text: text)
        expect(result).to be false
        expect(Rails.logger).to have_received(:warn).with(a_string_matching(/telegram_bot_dm.+chat not found/))
      end
    end

    context "when the network fails" do
      before { allow(Net::HTTP).to receive(:post_form).and_raise(Net::ReadTimeout) }

      it "swallows the error and returns false" do
        allow(Rails.logger).to receive(:warn)
        expect(described_class.call(chat_id: chat_id, text: text)).to be false
        expect(Rails.logger).to have_received(:warn).with(a_string_matching(/Net::ReadTimeout/))
      end
    end

    context "when bot_token is blank" do
      let(:bot_token) { nil }

      it "returns false without calling the API" do
        result = described_class.call(chat_id: chat_id, text: text)
        expect(result).to be false
        expect(Net::HTTP).not_to have_received(:post_form)
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/telegram/bot_dm_service_spec.rb`
Expected: FAIL — uninitialized constant.

- [ ] **Step 3: Implement the service**

Create `app/services/telegram/bot_dm_service.rb`:

```ruby
require "net/http"
require "json"

module Telegram
  class BotDmService
    BASE_URL = "https://api.telegram.org".freeze

    def self.call(chat_id:, text:)
      new.call(chat_id: chat_id, text: text)
    end

    def call(chat_id:, text:)
      token = Rails.application.config.x.telegram.bot_token
      return false if token.blank?

      uri = URI("#{BASE_URL}/bot#{token}/sendMessage")
      response = Net::HTTP.post_form(uri, {
        "chat_id" => chat_id.to_s,
        "text" => text,
        "disable_web_page_preview" => "true"
      })
      data = JSON.parse(response.body)

      return true if data["ok"]

      log_failure("api error: #{data["description"]}")
      false
    rescue JSON::ParserError,
           SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      log_failure("#{e.class}: #{e.message}")
      false
    end

    private

    def log_failure(detail)
      Rails.logger.warn({ event: "telegram_bot_dm.failed", detail: detail }.to_json)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/telegram/bot_dm_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `bundle exec rubocop app/services/telegram/bot_dm_service.rb spec/services/telegram/bot_dm_service_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/services/telegram/bot_dm_service.rb spec/services/telegram/bot_dm_service_spec.rb
git commit -m "feat(telegram): add BotDmService for operator feedback (vm-0kz)

Bot API sendMessage wrapper. Failures logged, never raised."
```

---

## Task 5: Locale strings

**Files:**
- Modify: `config/locales/ru.yml`

- [ ] **Step 1: Read the current ru.yml top-level structure**

Run: `head -40 config/locales/ru.yml`

This tells us where to insert the `telegram:` namespace (under the `ru:` root).

- [ ] **Step 2: Append the telegram.force_import namespace**

Add under the `ru:` root (alphabetised placement preferred — find the slot before `users:` or near other top-level domain namespaces):

```yaml
  telegram:
    force_import:
      bad_link: "Не понял ссылку. Пример: https://t.me/c/.../123 +5"
      disabled: "Force-import выключен"
      count_too_large: "Лимит диапазона %{max}. Передано: %{count}"
      no_access: "Бот не имеет доступа к чату источнику"
      no_messages: "Не удалось получить сообщения"
      no_author: "Автор сообщения не привязан к пользователю — черновик создан под вашим авторством, переназначьте в админке."
      success: "Черновик #%{id} создан (импортировано %{imported}/%{total}, %{skipped} пропущено — другой автор)."
```

- [ ] **Step 3: Verify YAML parses**

Run: `bundle exec ruby -ryaml -e "YAML.safe_load_file('config/locales/ru.yml')"` and confirm no error.

- [ ] **Step 4: Spot-check the keys load**

Run: `bundle exec rails runner 'puts I18n.t("telegram.force_import.disabled", locale: :ru)'`
Expected: `Force-import выключен`

- [ ] **Step 5: Commit**

```bash
git add config/locales/ru.yml
git commit -m "feat(i18n): add telegram.force_import.* keys (vm-0kz)"
```

---

## Task 6: `Telegram::ForceImportService` — happy path (single message)

This is the orchestrator. Implement it in slices, one TDD cycle per behaviour. This task covers the single-message happy path; later tasks add range, mixed-sender filter, author fallback, and error paths.

**Files:**
- Create: `app/services/telegram/force_import_service.rb`
- Test: `spec/services/telegram/force_import_service_spec.rb`

- [ ] **Step 1: Write the failing happy-path tests**

Create `spec/services/telegram/force_import_service_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Telegram::ForceImportService do
  let_it_be(:operator_user) { create(:user) }
  let_it_be(:operator_author) { create(:telegram_author, telegram_user_id: 12345, user: operator_user) }
  let_it_be(:sender_user) { create(:user) }
  let_it_be(:sender_author) { create(:telegram_author, telegram_user_id: 99999, user: sender_user) }

  let(:operator_chat_id) { 12345 }
  let(:source_chat) { -1001111111111 }
  let(:start_message_id) { 100 }

  let(:single_message_payload) do
    {
      "message_id" => 9001,
      "from" => { "id" => 0, "is_bot" => true },
      "text" => "A" * 50,
      "forward_origin" => {
        "type" => "user",
        "sender_user" => { "id" => 99999, "first_name" => "Sender" },
        "date" => 1_710_000_000
      }
    }
  end

  let(:parsed_link) do
    Telegram::MessageLinkParser::Result.new(
      source_chat: source_chat, message_id: start_message_id, count: 0
    )
  end

  before do
    FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
      ft.enabled = true
      ft.value = ""
      ft.description = "force_import"
    end
    allow(Telegram::BotDmService).to receive(:call).and_return(true)
    allow(NotifyEditorsAboutDraftService).to receive(:call)
    allow(AutolinkPlayersInNewsService).to receive(:call)
  end

  describe ".call (single message)" do
    before do
      allow(Telegram::ForwardMessageService).to receive(:call).and_return(
        Telegram::ForwardMessageService::Result.new(
          success: true, message: single_message_payload, error_code: nil, description: nil
        )
      )
    end

    it "creates exactly one News draft" do
      expect {
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      }.to change(News, :count).by(1)
    end

    it "calls forwardMessage with the parsed link parameters" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::ForwardMessageService).to have_received(:call).with(
        from_chat_id: source_chat, message_id: start_message_id, to_chat_id: operator_chat_id
      )
    end

    it "authors the draft as the sender's linked user" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.author).to eq(sender_user)
    end

    it "sets the draft status to :draft" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.status).to eq("draft")
    end

    it "uses the message text as the title" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.title).to eq("A" * 50)
    end

    it "sets created_at from forward_origin.date" do
      freeze_time do
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
        expect(News.last.created_at).to eq(Time.at(1_710_000_000))
      end
    end

    it "sets telegram_thread_started_at and _last_message_at to original date" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      news = News.last
      expect(news.telegram_thread_started_at).to eq(Time.at(1_710_000_000))
      expect(news.telegram_thread_last_message_at).to eq(Time.at(1_710_000_000))
    end

    it "runs the autolink service on the new draft" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(AutolinkPlayersInNewsService).to have_received(:call).with(News.last)
    end

    it "notifies editors" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(NotifyEditorsAboutDraftService).to have_received(:call).with(News.last)
    end

    it "DMs the operator a success ack" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id,
        text: a_string_including("Черновик #").and(including("импортировано 1/1"))
      )
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb`
Expected: FAIL — uninitialized constant.

- [ ] **Step 3: Implement minimal service**

Create `app/services/telegram/force_import_service.rb`:

```ruby
module Telegram
  class ForceImportService
    MAX_TITLE_LENGTH = 255
    PHOTO_ONLY_TITLE = "[медиа]".freeze
    DEFAULT_MAX_RANGE = 50

    def self.call(parsed_link:, operator_chat_id:, operator_user:)
      new(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user).call
    end

    def initialize(parsed_link:, operator_chat_id:, operator_user:)
      @parsed_link = parsed_link
      @operator_chat_id = operator_chat_id
      @operator_user = operator_user
    end

    def call
      forwarded = fetch_messages
      return dm_no_messages if forwarded.empty?

      first = forwarded.first
      sender_id = original_sender_id(first)
      same_sender = forwarded.select { |m| original_sender_id(m) == sender_id }

      author = resolve_author(sender_id)
      news = build_draft(same_sender, author)
      news.save!

      AutolinkPlayersInNewsService.call(news)
      NotifyEditorsAboutDraftService.call(news)

      dm_success(news, imported: same_sender.size, total: forwarded.size)
    end

    private

    def fetch_messages
      ids = (@parsed_link.message_id..@parsed_link.message_id + @parsed_link.count).to_a
      ids.filter_map { |id| forward_one(id) }
    end

    def forward_one(message_id)
      result = Telegram::ForwardMessageService.call(
        from_chat_id: @parsed_link.source_chat,
        message_id: message_id,
        to_chat_id: @operator_chat_id
      )
      return result.message if result.success

      nil
    end

    def original_sender_id(forwarded_msg)
      origin = forwarded_msg["forward_origin"]
      return origin["sender_user"]["id"] if origin.is_a?(Hash) && origin["sender_user"].is_a?(Hash)

      forwarded_msg.dig("forward_from", "id")
    end

    def original_date(forwarded_msg)
      origin = forwarded_msg["forward_origin"]
      return Time.at(origin["date"]) if origin.is_a?(Hash) && origin["date"].present?

      Time.at(forwarded_msg["forward_date"]) if forwarded_msg["forward_date"]
    end

    def resolve_author(sender_id)
      author = TelegramAuthor.find_by_telegram_user_id(sender_id)
      user = author&.ensure_user!
      return user if user.present?

      @operator_user
    end

    def build_draft(messages, author)
      first = messages.first
      first_text = first["text"].presence || first["caption"].presence
      title = first_text.present? ? first_text.truncate(MAX_TITLE_LENGTH) : PHOTO_ONLY_TITLE
      first_date = original_date(first) || Time.current

      News.new(
        title: title,
        content: first_text.to_s,
        author: author,
        status: :draft,
        created_at: first_date,
        telegram_thread_started_at: first_date,
        telegram_thread_last_message_at: original_date(messages.last) || first_date
      )
    end

    def dm_success(news, imported:, total:)
      Telegram::BotDmService.call(
        chat_id: @operator_chat_id,
        text: I18n.t("telegram.force_import.success", id: news.id, imported: imported, total: total, skipped: total - imported)
      )
    end

    def dm_no_messages
      Telegram::BotDmService.call(
        chat_id: @operator_chat_id,
        text: I18n.t("telegram.force_import.no_messages")
      )
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit (intermediate — happy path only)**

```bash
git add app/services/telegram/force_import_service.rb spec/services/telegram/force_import_service_spec.rb
git commit -m "feat(telegram): ForceImportService single-message happy path (vm-0kz)"
```

---

## Task 7: `Telegram::ForceImportService` — range + photos

Add range support and inline photo embedding (matching vm-z20 thread shape).

**Files:**
- Modify: `app/services/telegram/force_import_service.rb`
- Modify: `spec/services/telegram/force_import_service_spec.rb`

- [ ] **Step 1: Write the failing range tests**

Append to `spec/services/telegram/force_import_service_spec.rb`, inside the top-level describe:

```ruby
describe ".call (range)" do
  let(:parsed_link) do
    Telegram::MessageLinkParser::Result.new(
      source_chat: source_chat, message_id: start_message_id, count: 2
    )
  end

  let(:msg_a) { build_forwarded("AAA", 99999, message_id: 9001, date: 1_710_000_000) }
  let(:msg_b) { build_forwarded("BBB", 99999, message_id: 9002, date: 1_710_000_010) }
  let(:msg_c) { build_forwarded("CCC", 99999, message_id: 9003, date: 1_710_000_020) }

  def build_forwarded(text, sender_id, message_id:, date:)
    {
      "message_id" => message_id,
      "from" => { "id" => 0, "is_bot" => true },
      "text" => text,
      "forward_origin" => {
        "type" => "user",
        "sender_user" => { "id" => sender_id, "first_name" => "S" },
        "date" => date
      }
    }
  end

  before do
    allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
      payload =
        case message_id
        when 100 then msg_a
        when 101 then msg_b
        when 102 then msg_c
        end
      Telegram::ForwardMessageService::Result.new(success: payload.present?, message: payload, error_code: nil, description: nil)
    end
  end

  it "creates one consolidated draft" do
    expect {
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    }.to change(News, :count).by(1)
  end

  it "concatenates message text in order" do
    described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    body = News.last.content.body.to_plain_text
    expect(body.index("AAA")).to be < body.index("BBB")
    expect(body.index("BBB")).to be < body.index("CCC")
  end

  it "uses the first message's date for telegram_thread_started_at" do
    described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    expect(News.last.telegram_thread_started_at).to eq(Time.at(1_710_000_000))
  end

  it "uses the last message's date for telegram_thread_last_message_at" do
    described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    expect(News.last.telegram_thread_last_message_at).to eq(Time.at(1_710_000_020))
  end

  it "ack reports 3/3" do
    described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    expect(Telegram::BotDmService).to have_received(:call).with(
      chat_id: operator_chat_id, text: a_string_including("3/3")
    )
  end

  context "with gaps (deleted middle message returns 404)" do
    before do
      allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
        case message_id
        when 100
          Telegram::ForwardMessageService::Result.new(success: true, message: msg_a, error_code: nil, description: nil)
        when 101
          Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 400, description: "message not found")
        when 102
          Telegram::ForwardMessageService::Result.new(success: true, message: msg_c, error_code: nil, description: nil)
        end
      end
    end

    it "skips the gap and imports the rest" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      body = News.last.content.body.to_plain_text
      expect(body).to include("AAA").and include("CCC")
      expect(body).not_to include("BBB")
    end

    it "ack reports 2/2 (only successful forwards count)" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: a_string_including("2/2")
      )
    end
  end

  context "with an inline photo in a range message" do
    let(:photo_message) do
      {
        "message_id" => 9002,
        "from" => { "id" => 0, "is_bot" => true },
        "caption" => "with photo",
        "photo" => [
          { "file_id" => "small_id", "file_size" => 100, "width" => 90, "height" => 90 },
          { "file_id" => "large_id", "file_size" => 5000, "width" => 800, "height" => 800 }
        ],
        "forward_origin" => {
          "type" => "user",
          "sender_user" => { "id" => 99999, "first_name" => "S" },
          "date" => 1_710_000_010
        }
      }
    end

    let(:download_result) do
      Telegram::DownloadFileService::SuccessResult.new(
        io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg"
      )
    end

    before do
      allow(Telegram::DownloadFileService).to receive(:call).and_return(download_result)
      allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
        payload = case message_id
                  when 100 then msg_a
                  when 101 then photo_message
                  when 102 then msg_c
                  end
        Telegram::ForwardMessageService::Result.new(success: payload.present?, message: payload, error_code: nil, description: nil)
      end
    end

    it "downloads the largest photo" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::DownloadFileService).to have_received(:call).with("large_id")
    end

    it "embeds the photo inline in the draft body" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.content.body.to_html).to include("action-text-attachment")
    end

    it "does not attach photos to the gallery" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.photos).not_to be_attached
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb -e "(range)"`
Expected: FAIL on order, content concatenation, photo embedding.

- [ ] **Step 3: Extend `build_draft` to concat all messages and embed photos**

Replace `build_draft` and add helpers in `app/services/telegram/force_import_service.rb`:

```ruby
def build_draft(messages, author)
  first = messages.first
  first_text = first["text"].presence || first["caption"].presence
  title = first_text.present? ? first_text.truncate(MAX_TITLE_LENGTH) : PHOTO_ONLY_TITLE
  first_date = original_date(first) || Time.current
  last_date  = original_date(messages.last) || first_date

  News.new(
    title: title,
    content: assemble_content(messages),
    author: author,
    status: :draft,
    created_at: first_date,
    telegram_thread_started_at: first_date,
    telegram_thread_last_message_at: last_date
  )
end

def assemble_content(messages)
  messages.flat_map { |m| html_parts_for(m) }.join
end

def html_parts_for(message)
  parts = []
  parts << embedded_photo_html(extract_largest_photo_id(message)) if message["photo"].present?
  text = message["text"].presence || message["caption"].presence
  parts << format_html(text, message["entities"] || message["caption_entities"] || []) if text.present?
  parts
end

def format_html(text, entities)
  Telegram::EntitiesFormatter.call(text, entities)
end

def extract_largest_photo_id(message)
  photos = message["photo"]
  return nil if photos.blank?

  photos.max_by { |p| p["file_size"].to_i }["file_id"]
end

def embedded_photo_html(file_id)
  return "" if file_id.blank?

  result = Telegram::DownloadFileService.call(file_id)
  return "" unless result.success?

  blob = ActiveStorage::Blob.create_and_upload!(
    io: result.io, filename: result.filename, content_type: result.content_type
  )
  ActionText::Attachment.from_attachable(blob).to_html
end
```

- [ ] **Step 4: Run range tests to verify they pass**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/telegram/force_import_service.rb spec/services/telegram/force_import_service_spec.rb
git commit -m "feat(telegram): ForceImportService range + inline photo (vm-0kz)"
```

---

## Task 8: Mixed-sender filter

The first message's sender wins; later messages from different senders are skipped, and the ack DM reports the skipped count.

**Files:**
- Modify: `app/services/telegram/force_import_service.rb`
- Modify: `spec/services/telegram/force_import_service_spec.rb`

- [ ] **Step 1: Write the failing tests**

Append inside the existing `describe ".call (range)"` block:

```ruby
context "with messages from different senders inside the range" do
  let(:msg_b_other) { build_forwarded("BBB", 88888, message_id: 9002, date: 1_710_000_010) }

  before do
    allow(Telegram::ForwardMessageService).to receive(:call) do |from_chat_id:, message_id:, to_chat_id:|
      payload = case message_id
                when 100 then msg_a
                when 101 then msg_b_other
                when 102 then msg_c
                end
      Telegram::ForwardMessageService::Result.new(success: true, message: payload, error_code: nil, description: nil)
    end
  end

  it "includes only same-sender messages in the draft body" do
    described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    body = News.last.content.body.to_plain_text
    expect(body).to include("AAA").and include("CCC")
    expect(body).not_to include("BBB")
  end

  it "ack reports skipped count" do
    described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
    expect(Telegram::BotDmService).to have_received(:call).with(
      chat_id: operator_chat_id, text: a_string_including("2/3").and(including("1"))
    )
  end
end
```

- [ ] **Step 2: Run tests to verify**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb -e "different senders"`
Expected: PASS (filter logic already in place from Task 6). If FAIL, fix the filter in `#call`.

- [ ] **Step 3: Commit**

```bash
git add spec/services/telegram/force_import_service_spec.rb
git commit -m "test(telegram): cover mixed-sender filter in ForceImportService (vm-0kz)"
```

---

## Task 9: Author resolution fallback

Tests the three branches: linked-user author, stub-user fallback (vm-196 path), operator fallback when neither is available.

**Files:**
- Modify: `spec/services/telegram/force_import_service_spec.rb`
- (`app/services/telegram/force_import_service.rb` already has the logic from Task 6)

- [ ] **Step 1: Write the failing tests**

Append a new `describe ".call (author resolution)"` block to the top-level describe:

```ruby
describe ".call (author resolution)" do
  before do
    allow(Telegram::ForwardMessageService).to receive(:call).and_return(
      Telegram::ForwardMessageService::Result.new(success: true, message: single_message_payload, error_code: nil, description: nil)
    )
    allow(Telegram::BotDmService).to receive(:call).and_return(true)
    allow(AutolinkPlayersInNewsService).to receive(:call)
    allow(NotifyEditorsAboutDraftService).to receive(:call)
    FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
      ft.enabled = true
      ft.value = ""
      ft.description = "force_import"
    end
  end

  context "when sender has a TelegramAuthor with a linked user" do
    it "authors as that linked user" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.author).to eq(sender_user)
    end
  end

  context "when sender has a TelegramAuthor with no user but a player (vm-196 stub path)" do
    let_it_be(:player) { create(:player) }
    let_it_be(:stub_author) { create(:telegram_author, telegram_user_id: 77777, user: nil, player: player) }

    let(:single_message_payload) do
      {
        "message_id" => 9001,
        "from" => { "id" => 0, "is_bot" => true },
        "text" => "stub me",
        "forward_origin" => {
          "type" => "user",
          "sender_user" => { "id" => 77777, "first_name" => "Stub" },
          "date" => 1_710_000_000
        }
      }
    end

    it "authors with a stub user linked to the player" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.author).to be_telegram_stub
      expect(News.last.author.player).to eq(player)
    end
  end

  context "when sender has no TelegramAuthor row" do
    let(:single_message_payload) do
      {
        "message_id" => 9001,
        "from" => { "id" => 0, "is_bot" => true },
        "text" => "stranger",
        "forward_origin" => {
          "type" => "user",
          "sender_user" => { "id" => 11111, "first_name" => "Stranger" },
          "date" => 1_710_000_000
        }
      }
    end

    it "authors as the operator" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.author).to eq(operator_user)
    end

    it "DMs a warning to the operator" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: a_string_including("Автор сообщения не привязан")
      )
    end
  end

  context "when sender has a TelegramAuthor row but no user and no player" do
    let_it_be(:orphan_author) { create(:telegram_author, telegram_user_id: 22222, user: nil, player: nil) }

    let(:single_message_payload) do
      {
        "message_id" => 9001,
        "from" => { "id" => 0, "is_bot" => true },
        "text" => "orphan",
        "forward_origin" => {
          "type" => "user",
          "sender_user" => { "id" => 22222, "first_name" => "Orphan" },
          "date" => 1_710_000_000
        }
      }
    end

    it "falls back to the operator as author" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(News.last.author).to eq(operator_user)
    end

    it "DMs a warning" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: a_string_including("Автор сообщения не привязан")
      )
    end
  end
end
```

- [ ] **Step 2: Run tests to verify**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb -e "author resolution"`
Expected: FAIL on the "DMs a warning" assertions — the service currently sends only the success ack.

- [ ] **Step 3: Add the warning DM when author falls back to operator**

Edit `app/services/telegram/force_import_service.rb` — track fallback in `resolve_author` and DM warning before success:

```ruby
def call
  forwarded = fetch_messages
  return dm_no_messages if forwarded.empty?

  first = forwarded.first
  sender_id = original_sender_id(first)
  same_sender = forwarded.select { |m| original_sender_id(m) == sender_id }

  author, fell_back = resolve_author(sender_id)
  news = build_draft(same_sender, author)
  news.save!

  AutolinkPlayersInNewsService.call(news)
  NotifyEditorsAboutDraftService.call(news)

  dm_no_author if fell_back
  dm_success(news, imported: same_sender.size, total: forwarded.size)
end

# ...

def resolve_author(sender_id)
  author = TelegramAuthor.find_by_telegram_user_id(sender_id)
  user = author&.ensure_user!
  return [ user, false ] if user.present?

  [ @operator_user, true ]
end

def dm_no_author
  Telegram::BotDmService.call(
    chat_id: @operator_chat_id,
    text: I18n.t("telegram.force_import.no_author")
  )
end
```

- [ ] **Step 4: Run the author resolution tests**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb -e "author resolution"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/telegram/force_import_service.rb spec/services/telegram/force_import_service_spec.rb
git commit -m "feat(telegram): operator-as-author fallback with warning DM (vm-0kz)"
```

---

## Task 10: Error paths

Five error branches: feature disabled, count overflow, all forwards 403, all forwards 400, single forward 403 mid-range. The service has to refuse to act when disabled, refuse over-cap requests, and report no-access vs no-messages distinctly.

**Files:**
- Modify: `app/services/telegram/force_import_service.rb`
- Modify: `spec/services/telegram/force_import_service_spec.rb`

- [ ] **Step 1: Write the failing tests**

Append a new `describe ".call (errors)"` block:

```ruby
describe ".call (errors)" do
  before do
    allow(Telegram::BotDmService).to receive(:call).and_return(true)
    allow(AutolinkPlayersInNewsService).to receive(:call)
    allow(NotifyEditorsAboutDraftService).to receive(:call)
  end

  context "when the feature toggle is disabled" do
    before do
      FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
        ft.enabled = false
        ft.value = ""
        ft.description = "force_import"
      end
    end

    it "does not create a draft" do
      expect {
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      }.not_to change(News, :count)
    end

    it "DMs 'disabled'" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: I18n.t("telegram.force_import.disabled")
      )
    end

    it "does not call ForwardMessageService" do
      allow(Telegram::ForwardMessageService).to receive(:call)
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::ForwardMessageService).not_to have_received(:call)
    end
  end

  context "when count exceeds the max" do
    let(:parsed_link) do
      Telegram::MessageLinkParser::Result.new(source_chat: source_chat, message_id: start_message_id, count: 999)
    end

    before do
      FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
        ft.enabled = true
        ft.value = ""
        ft.description = "force_import"
      end
      FeatureToggle.find_or_create_by!(key: "telegram_force_import_max_range") do |ft|
        ft.enabled = true
        ft.value = "50"
        ft.description = "max_range"
      end
    end

    it "does not create a draft" do
      expect {
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      }.not_to change(News, :count)
    end

    it "DMs the count-too-large message with substituted limit and count" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: a_string_including("50").and(including("999"))
      )
    end
  end

  context "when ForwardMessageService returns 403 on every call" do
    before do
      FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
        ft.enabled = true
        ft.value = ""
        ft.description = "force_import"
      end
      allow(Telegram::ForwardMessageService).to receive(:call).and_return(
        Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 403, description: "Forbidden")
      )
    end

    it "DMs 'no access'" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_access")
      )
    end

    it "does not create a draft" do
      expect {
        described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      }.not_to change(News, :count)
    end
  end

  context "when ForwardMessageService returns only 400s" do
    before do
      FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
        ft.enabled = true
        ft.value = ""
        ft.description = "force_import"
      end
      allow(Telegram::ForwardMessageService).to receive(:call).and_return(
        Telegram::ForwardMessageService::Result.new(success: false, message: nil, error_code: 400, description: "not found")
      )
    end

    it "DMs 'no messages'" do
      described_class.call(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: I18n.t("telegram.force_import.no_messages")
      )
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb -e "errors"`
Expected: FAIL on disabled / overflow / 403 / 400 paths.

- [ ] **Step 3: Implement error guards**

Replace `#call` and add helpers in `app/services/telegram/force_import_service.rb`:

```ruby
ENABLED_TOGGLE = "telegram_force_import_enabled".freeze
MAX_RANGE_TOGGLE = "telegram_force_import_max_range".freeze

def call
  return dm_disabled unless FeatureToggle.enabled?(ENABLED_TOGGLE)
  return dm_count_too_large if @parsed_link.count > max_range

  results = fetch_results
  successful = results.select(&:success).map(&:message)

  return dm_no_access if successful.empty? && results.any? { |r| r.error_code == 403 }
  return dm_no_messages if successful.empty?

  first = successful.first
  sender_id = original_sender_id(first)
  same_sender = successful.select { |m| original_sender_id(m) == sender_id }

  author, fell_back = resolve_author(sender_id)
  news = build_draft(same_sender, author)
  news.save!

  AutolinkPlayersInNewsService.call(news)
  NotifyEditorsAboutDraftService.call(news)

  dm_no_author if fell_back
  dm_success(news, imported: same_sender.size, total: successful.size)
end

private

def max_range
  FeatureToggle.value_for(MAX_RANGE_TOGGLE, default: DEFAULT_MAX_RANGE).to_i
end

def fetch_results
  (@parsed_link.message_id..@parsed_link.message_id + @parsed_link.count).map do |id|
    Telegram::ForwardMessageService.call(
      from_chat_id: @parsed_link.source_chat,
      message_id: id,
      to_chat_id: @operator_chat_id
    )
  end
end

def dm_disabled
  Telegram::BotDmService.call(chat_id: @operator_chat_id, text: I18n.t("telegram.force_import.disabled"))
end

def dm_count_too_large
  Telegram::BotDmService.call(
    chat_id: @operator_chat_id,
    text: I18n.t("telegram.force_import.count_too_large", max: max_range, count: @parsed_link.count)
  )
end

def dm_no_access
  Telegram::BotDmService.call(chat_id: @operator_chat_id, text: I18n.t("telegram.force_import.no_access"))
end
```

Also delete the now-unused `fetch_messages` and `forward_one` helpers.

- [ ] **Step 4: Run all force_import_service specs**

Run: `bundle exec rspec spec/services/telegram/force_import_service_spec.rb`
Expected: PASS, all examples (happy path + range + author + errors).

- [ ] **Step 5: Lint**

Run: `bundle exec rubocop app/services/telegram/force_import_service.rb spec/services/telegram/force_import_service_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/services/telegram/force_import_service.rb spec/services/telegram/force_import_service_spec.rb
git commit -m "feat(telegram): ForceImportService error branches (vm-0kz)

Feature kill switch, range cap, 403 vs 400 distinction, DM-routed
operator feedback. Full happy/error coverage."
```

---

## Task 11: Wire dispatch in `ProcessTelegramWebhookJob`

The job needs an early dispatch: if the webhook payload looks like an operator DM with a force-import link, hand off to `ForceImportService`; otherwise run the existing pipeline.

**Files:**
- Modify: `app/jobs/process_telegram_webhook_job.rb`
- Modify: `spec/jobs/process_telegram_webhook_job_spec.rb`

- [ ] **Step 1: Write the failing dispatch tests**

Append to `spec/jobs/process_telegram_webhook_job_spec.rb`, inside `describe "#perform"`:

```ruby
context "with a force-import DM" do
  let(:operator_id) { 12345 }
  let(:operator_chat_id) { 12345 }

  let(:dm_payload) do
    {
      "update_id" => 5000,
      "message" => {
        "text" => "https://t.me/c/1111111111/678",
        "from" => { "id" => operator_id, "username" => "reporter", "first_name" => "Alex" },
        "chat" => { "id" => operator_chat_id, "type" => "private" },
        "date" => 1_710_000_000
      }
    }
  end

  before do
    FeatureToggle.find_or_create_by!(key: "telegram_force_import_enabled") do |ft|
      ft.enabled = true
      ft.value = ""
      ft.description = "force_import"
    end
    allow(Telegram::ForceImportService).to receive(:call)
  end

  it "dispatches to ForceImportService" do
    described_class.new.perform(dm_payload)
    expect(Telegram::ForceImportService).to have_received(:call).with(
      parsed_link: an_instance_of(Telegram::MessageLinkParser::Result),
      operator_chat_id: operator_chat_id,
      operator_user: user
    )
  end

  it "does not run the normal news-draft pipeline" do
    expect { described_class.new.perform(dm_payload) }.not_to change(News, :count)
  end

  context "when DM text is not a recognized link" do
    let(:dm_payload) do
      {
        "update_id" => 5001,
        "message" => {
          "text" => "hello bot",
          "from" => { "id" => operator_id, "username" => "reporter", "first_name" => "Alex" },
          "chat" => { "id" => operator_chat_id, "type" => "private" },
          "date" => 1_710_000_000
        }
      }
    end

    it "DMs help text" do
      allow(Telegram::BotDmService).to receive(:call).and_return(true)
      described_class.new.perform(dm_payload)
      expect(Telegram::BotDmService).to have_received(:call).with(
        chat_id: operator_chat_id, text: I18n.t("telegram.force_import.bad_link")
      )
    end

    it "does not dispatch to ForceImportService" do
      described_class.new.perform(dm_payload)
      expect(Telegram::ForceImportService).not_to have_received(:call)
    end
  end

  context "when DM is from a non-whitelisted sender" do
    let(:dm_payload) do
      {
        "update_id" => 5002,
        "message" => {
          "text" => "https://t.me/c/1111111111/678",
          "from" => { "id" => 99999, "username" => "stranger", "first_name" => "Bob" },
          "chat" => { "id" => 99999, "type" => "private" },
          "date" => 1_710_000_000
        }
      }
    end

    it "does not dispatch to ForceImportService and does not create a draft" do
      expect { described_class.new.perform(dm_payload) }.not_to change(News, :count)
      expect(Telegram::ForceImportService).not_to have_received(:call)
    end
  end
end
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `bundle exec rspec spec/jobs/process_telegram_webhook_job_spec.rb -e "force-import"`
Expected: FAIL — dispatch branch doesn't exist.

- [ ] **Step 3: Add dispatch branch to the job**

Edit `app/jobs/process_telegram_webhook_job.rb`. At the top of `#perform`, insert the dispatch ahead of the existing flow:

```ruby
def perform(payload)
  parsed = Telegram::MessageParser.call(payload)
  return if parsed.nil?

  return if dispatch_force_import?(payload, parsed)

  author = TelegramAuthor.find_by_telegram_user_id(parsed.from_id)
  return if author.nil?

  news_author = author.ensure_user!
  # ...rest unchanged
end
```

Add helpers (private):

```ruby
def dispatch_force_import?(payload, parsed)
  message = payload["message"] || payload["edited_message"]
  return false if message.nil?
  return false unless message.dig("chat", "type") == "private"

  operator_author = TelegramAuthor.find_by_telegram_user_id(parsed.from_id)
  return false if operator_author.nil?

  operator_user = operator_author.ensure_user!
  return false if operator_user.nil?

  link = Telegram::MessageLinkParser.call(parsed.raw_text)
  if link.nil?
    Telegram::BotDmService.call(
      chat_id: message.dig("chat", "id"),
      text: I18n.t("telegram.force_import.bad_link")
    )
    return true
  end

  Telegram::ForceImportService.call(
    parsed_link: link,
    operator_chat_id: message.dig("chat", "id"),
    operator_user: operator_user
  )
  true
end
```

- [ ] **Step 4: Run the new tests**

Run: `bundle exec rspec spec/jobs/process_telegram_webhook_job_spec.rb -e "force-import"`
Expected: PASS.

- [ ] **Step 5: Run the full job spec to confirm no regressions**

Run: `bundle exec rspec spec/jobs/process_telegram_webhook_job_spec.rb`
Expected: PASS, all examples. Group-chat / non-DM payloads from existing tests must still hit the original flow because their `chat.type` is missing or `"supergroup"`, not `"private"`.

If existing tests use `"chat" => { "id" => -100123 }` without `"type"`, the dispatch returns `false` (not `"private"`), so the legacy flow runs as before. Verify.

- [ ] **Step 6: Lint**

Run: `bundle exec rubocop app/jobs/process_telegram_webhook_job.rb spec/jobs/process_telegram_webhook_job_spec.rb`

- [ ] **Step 7: Commit**

```bash
git add app/jobs/process_telegram_webhook_job.rb spec/jobs/process_telegram_webhook_job_spec.rb
git commit -m "feat(telegram): wire force-import dispatch in webhook job (vm-0kz)

Detects private-chat DM from a whitelisted author whose body is a t.me
link, then hands off to ForceImportService. Bad links get a help DM.
Other DMs fall through to the existing pipeline (which silently drops
unknown senders)."
```

---

## Task 12: Lint + full suite

**Files:** none new.

- [ ] **Step 1: Rubocop pass on every file touched**

Run:
```
bundle exec rubocop \
  app/models/feature_toggle.rb \
  app/services/telegram/message_link_parser.rb \
  app/services/telegram/forward_message_service.rb \
  app/services/telegram/bot_dm_service.rb \
  app/services/telegram/force_import_service.rb \
  app/jobs/process_telegram_webhook_job.rb \
  spec/services/telegram/message_link_parser_spec.rb \
  spec/services/telegram/forward_message_service_spec.rb \
  spec/services/telegram/bot_dm_service_spec.rb \
  spec/services/telegram/force_import_service_spec.rb \
  spec/jobs/process_telegram_webhook_job_spec.rb
```
Expected: clean. Fix any offences. Re-run until clean.

- [ ] **Step 2: Full RSpec suite (minus excluded acceptance)**

Run: `bundle exec rspec --exclude-pattern 'spec/acceptance/**/*_spec.rb'`
Expected: PASS.

- [ ] **Step 3: Commit any lint fixes**

```bash
git status
git add -p   # only the lint-related changes
git commit -m "style: rubocop fixes for vm-0kz force-import"
```
(Skip if nothing changed.)

---

## Task 13: Mutation testing

Per CLAUDE.md workflow: evilution first, then mutant.

**Files:** none new. Append findings to `.artifacts.local/regular-evilution-feedback.log`.

- [ ] **Step 1: Evilution on each new service + modified job**

Run sequentially:

```bash
bundle exec evilution run app/services/telegram/message_link_parser.rb -j 4
bundle exec evilution run app/services/telegram/forward_message_service.rb -j 4
bundle exec evilution run app/services/telegram/bot_dm_service.rb -j 4
bundle exec evilution run app/services/telegram/force_import_service.rb -j 4
bundle exec evilution run app/jobs/process_telegram_webhook_job.rb -j 4
```

Fix any survivors by adding tests in the matching spec file.

- [ ] **Step 2: Mutant on each new service class**

```bash
bundle exec mutant run --jobs 4 -- 'Telegram::MessageLinkParser*'
bundle exec mutant run --jobs 4 -- 'Telegram::ForwardMessageService*'
bundle exec mutant run --jobs 4 -- 'Telegram::BotDmService*'
bundle exec mutant run --jobs 4 -- 'Telegram::ForceImportService*'
```

Fix any survivors.

- [ ] **Step 3: Append findings to `.artifacts.local/regular-evilution-feedback.log`**

Record:
- evilution version (`bundle exec evilution --version`)
- per-file scores (Evilution: X/Y, Mutant: X/Y)
- what mutant did better than evilution (or vice versa)
- gaps / suggestions

The file is gitignored — never commit.

- [ ] **Step 4: Re-run RSpec to make sure mutation-fix tests still pass**

Run: `bundle exec rspec spec/services/telegram spec/jobs/process_telegram_webhook_job_spec.rb spec/models/feature_toggle_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit any test additions made to kill mutants**

```bash
git add spec/
git commit -m "test(telegram): cover surviving mutants for force-import (vm-0kz)"
```

---

## Task 14: Verify, push, open PR

- [ ] **Step 1: `git pull` to be safe before push**

Run: `git pull --ff-only origin 852-force-import-specifically-targeted-telegram-messages-into-news-drafts || true`
(May 404 if branch isn't yet on remote — that's fine.)

- [ ] **Step 2: Push**

Run: `git push -u origin 852-force-import-specifically-targeted-telegram-messages-into-news-drafts`

- [ ] **Step 3: Get the GH issue id for `Closes`**

Run: `bd show vm-0kz | grep "External:"`
Expected: `External: gh-852`

- [ ] **Step 4: Open the PR**

```bash
gh pr create --title "feat(telegram): force-import targeted Telegram messages (vm-0kz)" --body "$(cat <<'EOF'
## Summary
- Operator (whitelisted Telegram author) DMs the bot a `t.me/...` message link with optional `+N` range → bot fetches via `forwardMessage` and creates a News draft.
- All four pipeline filters bypassed (min length, score threshold, whitelist of original sender, vm-z20 thread window).
- Same-sender range filter (matches vm-z20 batching semantics); skipped messages reported in ack DM.
- No noise in source chat: all bot interaction is in the operator's private DM with the bot.
- Closes #852

## Behaviour
- `<link>` → single message → one draft.
- `<link> +N` → consecutive `message_id` range → one consolidated draft. Gaps (deleted messages) silently skipped.
- Different-sender messages in range are skipped; ack reports `imported X/Y (Z skipped)`.
- Sender without `TelegramAuthor` row, or with row but no resolvable user/player: falls back to **operator as author** with a warning DM.
- Feature toggles: `telegram_force_import_enabled` (kill switch, default off), `telegram_force_import_max_range` (default 50).

## Mutation testing
- Evilution: see `.artifacts.local/regular-evilution-feedback.log` for per-file scores.
- Mutant: same.

## Test plan
- [ ] DM bot a single private-group link → draft created with original sender attribution.
- [ ] DM bot a link `+5` → one merged draft with 6 messages.
- [ ] DM bot a link from a sender without TelegramAuthor → draft authored to operator, warning DM received.
- [ ] DM bot a link to a deleted message → "Не удалось получить сообщения" DM.
- [ ] DM bot a link from a chat the bot is not in → "Бот не имеет доступа к чату источнику".
- [ ] Disable `telegram_force_import_enabled` → DM "Force-import выключен".
- [ ] DM bot junk text → "Не понял ссылку…" DM.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: Assign marinazzio**

```bash
PR_NUMBER=$(gh pr view --json number -q .number)
gh api repos/Port-Royal/vanilla-mafia/issues/${PR_NUMBER} --method PATCH -f "assignees[]=marinazzio"
```

- [ ] **Step 6: Update beads + close in-progress flag**

```bash
bd update vm-0kz --claim
# leave open until merge; do not bd close yet
```

- [ ] **Step 7: Return PR URL to user**

Run: `gh pr view --json url -q .url`

---

## Spec Coverage Self-Check

| Spec section | Implemented in |
|---|---|
| Trigger interface (link forms + `+N`) | Task 2 (parser) |
| Authorization (private chat + whitelisted sender) | Task 11 (dispatch) |
| Filters bypassed (all four) | Task 6 (single happy path), Task 7 (range), Task 11 (dispatch bypasses normal pipeline) |
| Range semantics (skip gaps, same-sender filter) | Task 7 (gaps), Task 8 (filter) |
| `forwardMessage` response shape (forward_origin, forward_date) | Task 6 `original_sender_id` / `original_date` helpers |
| Author resolution (3 branches incl. operator fallback) | Task 9 |
| Draft assembly (title, content, photos inline, thread cols) | Tasks 6 + 7 |
| Components (parser / forward / dm / force_import / job dispatch) | Tasks 2, 3, 4, 6, 11 |
| FeatureToggles (enabled, max_range) | Tasks 1, 10 |
| Error surface (7 DM cases) | Task 5 (locales), Tasks 10 + 11 (paths) |
| Tests (5 spec files) | Tasks 2, 3, 4, 6–10, 11 |
| Mutation testing | Task 13 |
| Out of scope items (idempotency, admin UI, multi-link, anonymous-admin) | Not implemented (deliberate) |
