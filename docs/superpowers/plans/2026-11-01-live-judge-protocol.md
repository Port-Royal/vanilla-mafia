# Live Judge Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Судья ведёт игру с клавиатуры ноутбука в живом протоколе, события сохраняются журналом, а оверлей показывает выставленных и проверки.

**Architecture:** Все правила игры лежат в чистом JS-модуле `machine.js`: действие судьи превращается в события, состояние считается повтором журнала. Сервер хранит события, проверяет их форму и применяет явно указанные исходы к `game_participations` и `games`. Stimulus-контроллер рисует экран и ведёт очередь отправки.

**Tech Stack:** Rails 8.1.2, Ruby 4.0.1, Stimulus, importmap, Action Cable, RSpec, Vitest и Stryker (только для разработки).

**Spec:** `docs/superpowers/specs/2026-11-01-live-judge-protocol-design.md`. Вид экрана: прототип https://claude.ai/artifact/W6Rtk5CHFYSsugaCCGkbNV, код из него не переносить.

## Global Constraints

- Клавиши сверяются по `event.code`, подписи латинские: раскладка не влияет.
- Все строки интерфейса через `ru.yml`, ключи `en` рядом.
- Доступ только `current_user.can_manage_protocols?` и `FeatureToggle.enabled?("live_protocol")`, иначе `head :not_found`.
- Журнал не уходит в `GameProtocolChannel`. При `hide_roles` роли и проверки не отдаются публично.
- Без `&.`, без `and return`. Спеки: `let_it_be`, `context`, без переменных внутри `it`.
- Ruby-код: `NO_COVERAGE=1 bundle exec evilution run <file> --jobs 1`, результат только в `.artifacts.local/regular-evilution-feedback.log`, не в GitHub.
- JS-код: `npx stryker run --mutate <file>`, результат только в `.artifacts.local/regular-evilution-feedback.log`, не в GitHub.
- Коммиты, ветки, push и PR только с разрешения пользователя. Ветка на задачу: `vanilla-mafia-<N>` от `master`.

## Review Focus

- Судья нажимает клавиши быстрее, чем уходят запросы: порядок событий на сервере совпадает с порядком нажатий (Task 8).
- Обрыв сети в разгар игры, потом перезагрузка страницы: неотправленные события не теряются (Task 8).
- Двойная отправка одного события после ретрая: запись одна (Task 3).
- Автоповтор при удержании `H` или потеря фокуса: роли не остаются открытыми (Task 7).
- Вся игра сыграна заново после `Ctrl+Z` назад через удаление: статусы в оверлее совпадают с журналом (Task 3).

---

## Task 1: Draw result

**Files:**
- Modify: `app/models/game.rb`, `app/models/game_participation.rb`, `app/views/judge/protocols/_form.html.erb` (радио строится из `Game.results`, менять не нужно, проверить), `config/locales/ru.yml`, `config/locales/en.yml`, `app/services/autosave_game_protocol_service.rb` (без изменений логики)
- Test: `spec/models/game_spec.rb`, `spec/models/game_participation_spec.rb`

**Interfaces:**
- Produces: `Game::RESULTS[:draw] == "draw"`; `GameParticipation#result` возвращает `"draw"`.

- [ ] **Step 1:** Падающие спеки: `Game.new(result: "draw")` валиден; `GameParticipation#result` даёт `"draw"` при `result: "draw"` и заполненной роли; `Game.finished` включает ничью.
- [ ] **Step 2:** `bundle exec rspec spec/models/game_spec.rb spec/models/game_participation_spec.rb`. Ожидание: FAIL.
- [ ] **Step 3:** Добавить значение и ветку `return "draw"`. Найти всех читателей: `grep -rn '"win"\|\.result\b' app`, для каждого решить показ ничьей; статистика побед ничью как победу не считает. Строка `activerecord.attributes.game.results.draw`.
- [ ] **Step 4:** Тот же запуск плюс `bundle exec rspec spec/requests/judge`. Ожидание: PASS.
- [ ] **Step 5:** Evilution по обеим моделям, коммит с разрешения.

## Task 2: Hidden roles are not served publicly

**Files:**
- Modify: `app/controllers/judge/protocols_controller.rb` (`broadcast_protocol_update`), `app/helpers/games_helper.rb` (`overlay_seat_roles`, `overlay_best_move_cells`), `app/views/games/overlay.html.erb`, `app/views/games/show.html.erb`
- Create: `app/services/broadcast_overlay_roles_service.rb`
- Test: `spec/requests/judge/protocols_autosave_spec.rb`, `spec/requests/games_spec.rb`

**Interfaces:**
- Produces: `Game#roles_public?` → `!(in_progress? && hide_roles?)`; `BroadcastOverlayRolesService.call(game:)` рассылает `{scope: "participation", seat:, field: "role_code", value:}` по всем местам.

- [ ] **Step 1:** Падающие спеки: при `hide_roles: true` и игре в процессе ответ `games#overlay` не содержит `don`/`sheriff` ни в атрибутах, ни в значках; `games#show` не показывает значки; autosave `role_code` не вызывает `broadcast_to`. При `hide_roles: false` всё как раньше. Выключение `hide_roles` через autosave и завершение игры рассылают роли.
- [ ] **Step 2:** Запуск: FAIL.
- [ ] **Step 3:** Реализовать через `roles_public?`. Также убрать значения цветов лучшего хода, пока роли закрыты.
- [ ] **Step 4:** Запуск плюс `spec/system` по оверлею: PASS.
- [ ] **Step 5:** Evilution, коммит с разрешения.

## Task 3: Event journal and server sync

**Files:**
- Create: `db/migrate/*_create_game_protocol_events.rb`, `app/models/game_protocol_event.rb`, `app/services/sync_protocol_event_service.rb`, `app/controllers/judge/live_protocols_controller.rb`, `app/controllers/judge/live_protocol_events_controller.rb`
- Modify: `config/routes.rb`, `app/models/feature_toggle.rb` (ключ `live_protocol`), `app/models/game.rb`
- Test: `spec/models/game_protocol_event_spec.rb`, `spec/services/sync_protocol_event_service_spec.rb`, `spec/requests/judge/live_protocol_events_spec.rb`

**Interfaces:**
- Produces, таблица `game_protocol_events`: `game_id`, `client_id` (string, unique `[game_id, client_id]`), `action_id` (string, indexed), `position` (integer, unique `[game_id, position]`), `kind` (string), `phase` (`deal|day|night`), `day_number` (integer), `actor_seat` (integer, null), `target_seats` (json, default `[]`), `text` (text), `metadata` (json, default `{}`), timestamps.
- Produces, маршруты: `GET /judge/protocols/:id/live`; `POST /judge/protocols/:id/live/events` с `{events: [...]}` отвечает `{saved: [client_id]}`; `DELETE /judge/protocols/:id/live/events/:action_id`.
- Produces: `GameProtocolEvent::KINDS` — `roles deal speaker suspect red team check_request nominate nomination_cancelled note vote round_closed round_cancelled vote_skipped shot miss_shot don_check sheriff_check night_closed best_move will foul tech sanction_cancelled player_left player_restored game_finished`.
- Produces: `GameProtocolEvent::DELETABLE_FROM_MIDDLE` — `suspect red team check_request note will best_move`, плюс `nominate`, если в дне нет событий `vote`.
- Produces: `SyncProtocolEventService.apply(event)` и `.revert(event)`.

Соответствие в `SyncProtocolEventService`:

| Событие | `apply` | `revert` |
|---|---|---|
| `roles` (`metadata.roles` `{seat: code}`) | `role_code` | очистить `role_code` |
| `player_left` (`metadata.reason`: `killed`, `voted`, `removed`) | `status`: `killed_by_mafia`, `voted_out`, `banned` | `alive` |
| `player_restored` | `alive` | `banned` |
| `best_move` | `best_move_seats` у `actor_seat` | очистить |
| `game_finished` (`metadata.result`) | `games.result`, `BroadcastOverlayRolesService` | запрещён |

Каждое изменение рассылается тем же форматом, что и autosave. Роли проходят через `Game#roles_public?`.

- [ ] **Step 1:** Падающие спеки модели: валидность `kind`, `phase`, диапазон мест 1..10, отказ при `metadata`-типах не из `Hash`.
- [ ] **Step 2:** Падающие request-спеки: повторный POST с тем же `client_id` создаёт одну запись и отвечает `saved`; порядок позиций соблюдается; игра не `in_progress` даёт 409; DELETE удаляет всю группу `action_id` и вызывает `revert`; удаление из середины не разрешённого вида даёт 422; без доступа и при выключенном флаге 404. Сквозной спек: `player_left` и его удаление возвращают `status` в `alive`.
- [ ] **Step 3:** Запуск: FAIL.
- [ ] **Step 4:** Реализовать. POST идёт одной транзакцией. `show` отдаёт страницу с `players` и `events` в data-атрибутах, пока заглушка.
- [ ] **Step 5:** `bundle exec rspec spec/models/game_protocol_event_spec.rb spec/services/sync_protocol_event_service_spec.rb spec/requests/judge/live_protocol_events_spec.rb`: PASS.
- [ ] **Step 6:** Evilution с `--spec` на эти файлы, коммит с разрешения.

## Task 4: Machine, setup and speeches

**Files:**
- Create: `app/javascript/live_protocol/machine.js`, `test/javascript/live_protocol/machine_speech.test.js`
- Modify: `config/importmap.rb` (`pin_all_from "app/javascript/live_protocol", under: "live_protocol"`), `.github/workflows/ci.yml` (шаг `npm test`)

**Interfaces:**
- Produces: `replay(players, events) -> state`; `decide(state, action) -> {events: [event], error: string|null}`. `action` это `{type, seats?, text?}`. `event` это `{kind, phase, day_number, actor_seat, target_seats, text, metadata}`. Без обращений к DOM и сети.
- Produces, поля состояния: `stage` (`roles deal speech vote leaving best_move night_shot night_miss night_don night_sheriff finished`), `day`, `speaker`, `firstSpeaker`, `candidates`, `players[seat] {role, fouls, tech, out, outReason}`, `round`, `nights`, `leaving`, `noVoteDay`, `pendingResult`, `log`.

- [ ] **Step 1:** Падающие тесты, значения из раздела спека «Речь» и «Роли судьи»: раздача требует ровно 1 дона, 1 шерифа, 2 мафии; договорка хранит статику/динамику, шерифа, текст; речь начинает игрок 1, в следующий день следующий живой; второе выставление того же игрока и выставление уже выставленного дают `error`; снятие кандидатуры снова разрешает выставить; `Space` на последнем запускает голосование; первый говорящий удалён, круг всё равно заканчивается.
- [ ] **Step 2:** `npm test`: FAIL.
- [ ] **Step 3:** Реализовать.
- [ ] **Step 4:** Запуск: PASS. Коммит с разрешения.

## Task 5: Machine, voting and removals

**Files:**
- Modify: `app/javascript/live_protocol/machine.js`
- Test: `test/javascript/live_protocol/machine_vote.test.js`

**Interfaces:**
- Produces: `voteDecided(round, aliveSeats) -> boolean`.

- [ ] **Step 1:** Падающие тесты по разделам «Голосование», «Нарушения», «Удаление и голосование»:
  - последний кандидат получает не проголосовавших; 9 игроков, кандидаты 1 2 3 4 5, 5 и 4 голоса: итог сразу по `Enter`;
  - один кандидат в нулевом круге и ноль кандидатов: ночь без голосования;
  - ничья: повтор; ничья с меньшим числом кандидатов: снова повтор; ничья с тем же числом: подъём, большинство от живых;
  - подъём не ставится: 5 или 10 кандидатов в нулевом круге, 3 кандидата при 9 живых в любой день, кандидатов больше половины живых;
  - 4-й фол и 2-й техфол удаляют; снятие санкции возвращает игрока, но не кандидатуру и не отменённое голосование;
  - из 10 живых 5 голосов и удаление: `noVoteDay` следующий день, текущее голосование идёт; 3 голоса: отмена сразу, следующий день голосует;
  - удаление в речах отменяет сегодня, второе удаление ничего не меняет; в уходящей речи после голосования отменяет завтра;
  - отданный голос удалённого остаётся; удалённый лидер без последней речи.
- [ ] **Step 2:** Запуск: FAIL.
- [ ] **Step 3:** Реализовать.
- [ ] **Step 4:** Запуск: PASS. Коммит с разрешения.

## Task 6: Machine, night, best move, will, end

**Files:**
- Modify: `app/javascript/live_protocol/machine.js`
- Create: `app/javascript/live_protocol/will_parser.js`
- Test: `test/javascript/live_protocol/machine_night.test.js`, `test/javascript/live_protocol/will_parser.test.js`

**Interfaces:**
- Produces: `parseWill(raw) -> {red: number[], black: number[], sheriff: number[], plan: string}`.
- Produces: действие `finish_game` с `result` (`peace_victory`, `mafia_victory`, `draw`) выдаёт `game_finished`.

- [ ] **Step 1:** Падающие тесты:
  - `parseWill`: `234к, 67ч, 9ш` и `2 3 4 r 6 7 b 9 s` дают `[2,3,4]`, `[6,7]`, `[9]`; `10к, 1ч` даёт `[10]`, `[1]`; `210к стреляйте в 8 завтра` даёт `[2,10]` и план; `просто план` только план;
  - отстрел одной целью, промах по каждому стреляющему с `не стрелял` и `тактический промах`; цели только живые; проверки пропускаются при мёртвом исполнителе; результаты проверок;
  - лучший ход идёт до завещания; ночной только в Ночь 1; после промаха в Ночь 1 в следующие ночи нет; при 2+ ушедших в нулевом круге принимается с `metadata.no_points: true`; дневной один ушедший голосованием в нулевом круге; голос за себя, включая автоматический, дневного хода не даёт, но `B` записывает;
  - победа мирных и мафии задают `pendingResult`, стадия остаётся для завещания, `finish_game` завершает; три ночи без изменения числа живых выставляют `drawSuggested`; удаление стрелка в ночи пропускает его шаг.
- [ ] **Step 2:** Запуск: FAIL.
- [ ] **Step 3:** Реализовать.
- [ ] **Step 4:** Запуск: PASS. Коммит с разрешения.

## Task 7: Console screen and keyboard

**Files:**
- Create: `app/javascript/controllers/live_protocol_controller.js`, `app/views/judge/live_protocols/show.html.erb`
- Modify: `config/locales/ru.yml`, `config/locales/en.yml`, `app/controllers/judge/protocols_controller.rb` (`after_save_path`), `app/views/judge/protocols/edit.html.erb` (взаимные ссылки), `spec`
- Test: `spec/system/judge/live_protocol_spec.rb`

**Interfaces:**
- Consumes: `replay`, `decide`, `parseWill`.
- Produces: контроллер держит `this.events`, вызывает `this.send(events)` (заглушка до Task 8).

- [ ] **Step 1:** Падающие системные спеки: сквозная короткая игра только с клавиатуры, с подписями клавиш по спеку; `0` как место 10; `Esc` отменяет; номер без действия не пишет; роли днём отсутствуют в DOM, при удержании `H` появляются, при отпускании и при `blur` исчезают, автоповтор клавиши не перерисовывает; в конце игры раскрыты; поле завещания получает фокус; `Ctrl+Z` откатывает группу действия.
- [ ] **Step 2:** `bundle exec rspec spec/system/judge/live_protocol_spec.rb`: FAIL.
- [ ] **Step 3:** Реализовать экран по разделу «Экран» и таблицам клавиш в спеке. В скрытом режиме секретные значения не попадают в DOM, а не прячутся стилями. Новая игра в процессе после создания при включённом флаге открывает живой протокол.
- [ ] **Step 4:** Запуск: PASS. Коммит с разрешения.

## Task 8: Send queue and restore

**Files:**
- Create: `app/javascript/live_protocol/send_queue.js`, `test/javascript/live_protocol/send_queue.test.js`
- Modify: `app/javascript/controllers/live_protocol_controller.js`
- Test: `spec/system/judge/live_protocol_offline_spec.rb`

**Interfaces:**
- Produces: `new SendQueue({post, remove, storage, onStatus})`, методы `enqueue(events)`, `enqueueDelete(actionId)`, `flush()`. Запросы идут строго по одному. `storage` это `localStorage` с ключом по игре.

- [ ] **Step 1:** Падающие тесты: порядок сохраняется при быстрых вызовах; ошибка сети оставляет элементы и повторяет с паузой 1, 2, 5, 5… секунд; `onStatus` даёт `saved`, `saving`, `offline`; перезапуск с тем же `storage` продолжает очередь; удаление ещё не отправленной группы убирает её из очереди без запроса.
- [ ] **Step 2:** Системный спек: события отправлены, страница перезагружена, игра на том же этапе; локальные неотправленные события применяются поверх журнала сервера без дублей по `client_id`.
- [ ] **Step 3:** Запуск: FAIL.
- [ ] **Step 4:** Реализовать, показать статус связи на экране.
- [ ] **Step 5:** `npm test` и системный спек: PASS. Коммит с разрешения.

## Task 9: Game record tab and protection of the form

**Files:**
- Create: `app/javascript/live_protocol/game_sheet.js`, `test/javascript/live_protocol/game_sheet.test.js`
- Modify: `app/javascript/controllers/live_protocol_controller.js`, `app/services/autosave_game_protocol_service.rb`, `app/services/save_game_protocol_service.rb`
- Test: `spec/services/autosave_game_protocol_service_spec.rb`, `spec/requests/judge/protocols_spec.rb`

**Interfaces:**
- Produces: `buildSheet(state, {rolesShown}) -> {deal, shots, misses, checks, rounds, wills, bestMoves, sheriffBonusHint}`.

- [ ] **Step 1:** Падающие тесты `buildSheet`: стрельба `X` при промахе; кто за кого голосовал по раундам, включая повтор и подъём; пометка «без баллов» у лучшего хода; подсказка только при убитом в Ночь 1 шерифе и динамике; при `rolesShown: false` нет `deal`, `misses`, `checks`, `sheriffBonusHint`.
- [ ] **Step 2:** Падающие спеки: смена или удаление игрока на месте через autosave и форму при наличии событий журнала отклоняется с понятной ошибкой; `role_code` и остальные поля правятся как раньше.
- [ ] **Step 3:** Запуск обоих: FAIL.
- [ ] **Step 4:** Реализовать вкладку «Бланк», форму защитить в обоих сервисах.
- [ ] **Step 5:** Запуск: PASS. Evilution по сервисам, коммит с разрешения.

## Task 10: Overlay, nominated players

**Files:**
- Modify: `app/services/sync_protocol_event_service.rb`, `app/javascript/controllers/game_overlay_controller.js`, `app/views/games/overlay.html.erb`, `app/controllers/games_controller.rb`, стили оверлея
- Test: `spec/services/sync_protocol_event_service_spec.rb`, `spec/requests/games_spec.rb`, `spec/system/games/overlay_*`

**Interfaces:**
- Consumes: `GameProtocolEvent`.
- Produces: `Game#current_nominees -> [seat]`; рассылка `{scope: "nominees", seats: [...]}` при `nominate`, `nomination_cancelled`, `night_closed`, начале ночи и при откате этих событий.

- [ ] **Step 1:** Падающие спеки: состав и порядок после выставления, снятия, отката; пусто с началом ночи; страница оверлея при загрузке показывает текущий список.
- [ ] **Step 2:** Запуск: FAIL.
- [ ] **Step 3:** Реализовать, вид блока в стиле оверлея.
- [ ] **Step 4:** Запуск: PASS. Evilution, коммит с разрешения.

## Task 11: Overlay, sheriff and don checks

**Files:**
- Modify: те же файлы, что в Task 10, плюс `app/controllers/judge/protocols_controller.rb` (переключение `hide_roles`)
- Test: те же, плюс `spec/requests/judge/protocols_autosave_spec.rb`

**Interfaces:**
- Produces: `Game#public_checks -> [{night:, kind:, target_seat:, result:}]`, пустой массив при закрытых ролях; `result`: `sheriff`, `not_sheriff`, `red`, `black`; рассылка `{scope: "checks", checks: [...]}`.

- [ ] **Step 1:** Падающие спеки: при `hide_roles: false` проверка рассылается и видна при загрузке; при `hide_roles: true` её нет ни в рассылке, ни в HTML; выключение `hide_roles` присылает накопленные, включение присылает пустой список; откат события убирает проверку.
- [ ] **Step 2:** Запуск: FAIL.
- [ ] **Step 3:** Реализовать.
- [ ] **Step 4:** Запуск: PASS. Evilution, коммит с разрешения.

## Task 12: Filter events by player after the game

**Files:**
- Create: `app/javascript/live_protocol/player_events.js`, `test/javascript/live_protocol/player_events.test.js`
- Modify: `app/javascript/controllers/live_protocol_controller.js`
- Test: `spec/system/judge/live_protocol_spec.rb`

**Interfaces:**
- Consumes: `state.log` из `replay`, `parseWill`.
- Produces: `playerEvents(state, seat) -> {actions: [entry], received: [entry]}`, порядок хронологический. `entry` сохраняет фазу и день исходной записи.

- [ ] **Step 1:** Падающие тесты: `actions` содержит события с `actor_seat == seat` и голоса этого игрока; `received` содержит события, где он среди `target_seats`, голоса за него, завещание с его номером (через `parseWill`), лучший ход с его номером; запись о подозрении игрока 1 в игрока 4 есть в `actions` у 1 и в `received` у 4, у игрока 5 её нет; свой голос за себя есть в обоих блоках.
- [ ] **Step 2:** Падающий системный спек: завершённая игра, номер показывает блоки выбранного игрока, `0` выбирает место 10, `Esc` снимает фильтр; у незавершённой игры цифры фильтр не включают; повторное открытие завершённой игры фильтр сохраняет как возможность.
- [ ] **Step 3:** Запуск обоих: FAIL.
- [ ] **Step 4:** Реализовать.
- [ ] **Step 5:** `npm test` и системный спек: PASS. Коммит с разрешения.
