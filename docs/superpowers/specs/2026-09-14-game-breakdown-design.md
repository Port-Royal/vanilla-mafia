# Game Breakdown (структурированный разбор игры)

**Issue:** gh-942 (epic)
**Date:** 2026-09-14
**Rules reference:** «Лига Азии — Официальные правила игры «Мафия»», редакция от 01.09.2026

## Goal

A new, internal tool for **analysing any game of mafia after the fact** — a club game or (most often) a third-party
game with unregistered players (tournament stream, video, etc.). It is **not** a replacement for or an extension of the
existing judge protocols (`Judge::ProtocolsController`), which record game outcomes and points.

A breakdown records the flow of the game as a chronology of **phases**, **game events** and **player moves**:

- Phases: zero round → night 1 → round at N players → night 2 → … → «угадайка на троих».
- Events: voting, mafia shots, don/sheriff checks, removals, farewell speeches of leaving players.
- Moves: sheriff reveals, voiced checks, nominations, check requests, split breaks, «крышевание», best move, other.

## Constraints and decisions

- Table always has 10 seats (1..10). Seat has a free-text name; link to a site `Player` is optional.
- A breakdown may optionally be linked to a club `Game` (seats pre-filled from its protocol). Third-party games are the
  primary case.
- Roles may be known from the start, or unknown.
- Breakdown has a **roles mode**: `open` or `closed`.
  - `open`: night internals are recorded (each mafia shot on a miss, don check, sheriff check).
  - `closed`: only the night outcome known in the morning (killed seat / miss). Checks exist only as day moves
    (`check_claim`), which may be false.
- Phase names and alive counts are derived automatically from events.
- Rule violations are **highlighted only** (warnings), never block saving — the breakdown records what actually happened.
- Move type catalogue lives in code (enum). New types require development.
- A foul is not recorded as such. What a player did under a foul is recorded as a regular move (usually `other`), with
  the actor who is not necessarily the speaker. Removal (4 fouls / 2 technical fouls / disqualification) is a move.
- Access: internal only — users with `judge` or `admin` grant, behind feature toggle `game_breakdown` (off by default).
  No public page.

## Data model

Seats are referenced **by number (1..10)** everywhere (actor, target, voter, candidate). Names/roles come from
`breakdown_seats` by number.

### `game_breakdowns`

| Column | Type | Notes |
|---|---|---|
| `title` | string, not null | |
| `played_on` | date, null | |
| `source` | string, null | tournament / event, free text |
| `video_url` | string, null | |
| `judge_name` | string, null | free text |
| `author_id` | references(users), not null | set to current user |
| `roles_mode` | string, not null, default `open` | enum `open` / `closed` |
| `game_id` | references(games), null | optional link to a club game |
| `manual_result` | string, null | enum `city` / `mafia` / `draw`; used when result cannot be computed |
| `conclusion` | text, null | overall conclusions (e.g. "covered the sheriff") |

### `breakdown_seats`

| Column | Type | Notes |
|---|---|---|
| `game_breakdown_id` | references, not null | |
| `number` | integer, not null | 1..10, unique per breakdown |
| `name` | string, null | |
| `player_id` | references(players), null | |
| `role_code` | string, null | FK to `roles.code` |

All 10 seats are created together with the breakdown. When `game_id` is set on creation, name / player / role are copied
from the game's participations by seat.

### `breakdown_phases`

| Column | Type | Notes |
|---|---|---|
| `game_breakdown_id` | references, not null | |
| `position` | integer, not null | unique per breakdown; `0` = zero round, odd = night, even = day |
| `night_outcome` | string, null | night only: enum `kill` / `miss`; null = not filled |
| `killed_seat` | integer, null | night only, when `night_outcome = kill` |

### `breakdown_night_actions` (open roles mode only)

| Column | Type | Notes |
|---|---|---|
| `breakdown_phase_id` | references, not null | |
| `kind` | string, not null | enum `mafia_shot` / `don_check` / `sheriff_check` |
| `actor_seat` | integer, null | shooter for `mafia_shot`; implied by role for checks |
| `target_seat` | integer, null | null for `mafia_shot` = did not shoot |

`mafia_shot` rows are recorded per alive mafia member when the night is a miss. Check results are derived from the target
seat's role (don: sheriff / not sheriff; sheriff: red / black).

### `breakdown_speeches`

| Column | Type | Notes |
|---|---|---|
| `breakdown_phase_id` | references, not null | day phases only |
| `speaker_seat` | integer, not null | |
| `kind` | string, not null | enum `regular` / `farewell` / `justification` |
| `position` | integer, not null | order within the phase |
| `breakdown_vote_round_id` | references, null | for `justification`: the revote round it precedes |

### `breakdown_vote_rounds`

| Column | Type | Notes |
|---|---|---|
| `breakdown_phase_id` | references, not null | |
| `number` | integer, not null | 1.. within the phase |
| `kind` | string, not null | enum `main` / `revote` / `lift` |

Candidates are not stored: `main` — nominations of the day in nomination order; `revote` — tied candidates of the
previous round; `lift` — tied candidates of the previous round.

### `breakdown_votes`

| Column | Type | Notes |
|---|---|---|
| `breakdown_vote_round_id` | references, not null | |
| `voter_seat` | integer, not null | unique per round |
| `candidate_seat` | integer, null | required for `main` / `revote` |
| `for_lift` | boolean, null | required for `lift` |

The final vote of each player is stored. Dynamics ("added a hand", "shouted to drop hands") are `other` moves in the round.

### `breakdown_moves`

| Column | Type | Notes |
|---|---|---|
| `breakdown_speech_id` | references, null | exactly one of speech / vote round |
| `breakdown_vote_round_id` | references, null | |
| `position` | integer, not null | order within the context |
| `kind` | string, not null | see catalogue |
| `actor_seat` | integer, not null | defaults to the speaker |
| `target_seat` | integer, null | |
| `claimed_color` | string, null | enum `red` / `black` |
| `night_number` | integer, null | |
| `best_move_seats` | json, null | array of 1..3 seat numbers |
| `removal_reason` | string, null | enum `fouls` / `technical_fouls` / `disqualification` |
| `text` | text, null | comment (any kind); required for `other` |

### Move catalogue

| Kind | Meaning | Required fields |
|---|---|---|
| `sheriff_reveal_table` | reveals as sheriff to the table | — |
| `sheriff_reveal_to_player` | reveals as sheriff to a specific player | `target_seat` |
| `check_claim` | voices a check ("my check is red" / "5 is black") | `claimed_color`, `night_number`; `target_seat` optional |
| `nomination` | nominates for voting | `target_seat` |
| `check_request` | asks to check a player | `target_seat` |
| `split_break` | breaks a split | `target_seat` optional |
| `protection` | «крышевание» | `target_seat` |
| `best_move` | best move (night or day) | `best_move_seats` (1..3) |
| `removal` | removal / disqualification; actor = removed player | `removal_reason` |
| `other` | anything else | `text` |

`check_claim.night_number` defaults in the UI to the last passed night; editable (sheriffs may voice several hidden checks
at once).

## Timeline (computed, not stored)

`GameBreakdown::Timeline` replays phases in order and exposes, per phase:

- alive seats at phase start and end;
- phase label: «Нулевой круг», «Ночь N», «Круг при {alive}», «Угадайка на троих» (day with 3 alive);
- day starter and speech order;
- nominations (ordered), vote rounds with tallies and outcomes (eliminated / tie / nobody);
- eliminated seats and the reason (night kill, vote, removal);
- expected next steps (used for automatic block creation);
- warnings;
- game result.

### Rules

- **Speech order.** Zero round starts at seat 1. Each next day starts at the next alive seat after the previous day's
  starter (circular). The farewell speech of the seat killed at night opens the next day, before regular speeches.
- **Night kill.** `open`: `night_outcome` / `killed_seat`; per-mafia shots on miss. `closed`: `night_outcome` /
  `killed_seat` only.
- **Voting** (4.4):
  - Candidates of `main` — nominations in order (by speech position, then move position).
  - A non-voting player's vote defaults to the last nominee (4.4.9) — pre-filled in the UI.
  - Single max → that seat leaves.
  - Tie → justification speeches of tied candidates (in nomination order) + `revote`.
  - Tie again among fewer candidates → another justification + `revote` (4.4.13.2).
  - Tie again among the same number of candidates → `lift` round, no speeches (4.4.13.3). Lift passes when strictly more
    than half of alive players vote for it; then all candidates leave, otherwise nobody.
  - Zero round with a single nominee → no voting (4.4.11). Splits in the zero round follow the same rules.
- **Removal.** Removed player leaves immediately without a farewell speech (6.6). A removal before the voting result
  cancels that day's voting (4.4.15).
- **Farewell speeches.** Voted-out and night-killed players get a farewell speech; removed players do not.
- **Best move.** Optional `best_move` in the farewell speech of the first night-killed player (4.5.10), or a day best move
  of a player leaving the zero round by a split break (4.4.20).
- **Result.**
  - Computable when every seat has a role: alive mafia = 0 → `city`; alive mafia ≥ alive red → `mafia`;
    alive count unchanged through three consecutive nights → `draw` (4.4.19).
  - Otherwise `manual_result` is used.
  - Once a result is determined, "+ next phase" is hidden.

### Warnings (non-blocking)

Each warning is attached to a phase/block and carries a rules reference.

- Speech or move by an eliminated seat (except its own farewell speech).
- Nomination / vote / target pointing to an eliminated seat.
- More than one nomination by the same player in a day (4.4.2).
- Vote for a seat that is not a candidate of the round.
- Voting held in the zero round with a single nominee (4.4.11).
- Voting held after a removal on that day (4.4.15).
- `lift` round held when forbidden: 5 or 10 candidates in the zero round (4.4.16); 3 candidates with 9 alive (4.4.17);
  more than half of alive players as candidates (4.4.18).
- Best move without the right: 2+ players left on the first day, or a miss on the first night (6.11.4); day best move after
  breaking into oneself (7.5.8).
- `check_claim.night_number` greater than the number of passed nights.
- `open` mode: a role needed for computation (mafia / don / sheriff) is missing; don/sheriff check by an eliminated seat.
- A block that no longer matches the timeline (e.g. farewell speech of a seat that was not eliminated after a correction).

## Editing behaviour

- **Creation.** Form: metadata, roles mode, optional `Game`. Creates 10 seats (pre-filled from `Game` if linked) and
  phase 0. Redirects to the editor.
- **"+ next phase"** is a manual button. It creates:
  - night: an empty night phase;
  - day: farewell speech of the night-killed seat (if any) and regular speeches of all alive seats in speech order.
- **Automatic step creation.** When the timeline expects a new block, it is created on save:
  - nominations exist and no `main` round → `main` round;
  - round ends in a tie → justification speeches + `revote`, or `lift`;
  - someone is voted out → farewell speeches.
- **No automatic deletion.** If a correction makes a block obsolete, it stays and is flagged; the judge edits or deletes it.
- Any block, move and vote can be edited or deleted. Only the **last phase** can be deleted.

## UI

Hotwire (Turbo Frames + Turbo Streams); Stimulus only for small things (move form fields switching by kind, autosubmit).

- **Index** `/judge/breakdowns` — table (title, date, source, author, result), "+ new breakdown".
- **Editor** `/judge/breakdowns/:id/edit` — single page, top to bottom:
  1. Header: metadata and roles mode, inline, saved on field change.
  2. Seats: 10 rows — number, name (free text with suggestions from site players; picking one sets `player_id`),
     role (select, may be empty).
  3. Phases: each in a `turbo_frame`, titled by the timeline label, with the alive list.
     - Day: speeches → vote rounds → justification speeches / revotes → farewell speeches.
     - Speech: speaker and its moves; "+ move" opens an inline form (kind → kind-specific fields → save).
     - Vote round: candidates, one row per alive voter with a candidate select (or for/against for `lift`); round moves.
     - Night: fields depend on roles mode.
     - Saving a block re-renders via Turbo Stream the affected phase and all following phases (labels, alive, warnings).
  4. Warnings — highlighted plate next to the block.
  5. Footer: "+ next phase", "delete last phase", result (computed or manual select), conclusion.
  - Mobile: single column; vote rows become cards.
- **View** `/judge/breakdowns/:id` — read-only: header, seats with roles, compact chronology (speeches as move lines,
  votes as "candidate — votes (who)" tables, nights as one line, e.g. «Убит 4 · Дон → 7 · Шериф → 2 (чёрный)»),
  warnings, result, conclusion.

## Access, toggle, i18n, admin

- Routes inside `authenticate :user, ->(u) { u.can_manage_protocols? }` (judge or admin).
- `Judge::Breakdowns*` controllers return 404 unless `FeatureToggle.enabled?("game_breakdown")`.
- `game_breakdown` added to `FeatureToggle::KEYS`, off by default.
- "Разборы" link in the judge menu, shown only when the toggle is on.
- All labels, phase names, move kinds and warning texts in `ru.yml` and `en.yml`.
- Avo resource `GameBreakdown`: index, show, delete, edit metadata. Nested entities are edited only in the editor.

## Testing

- Model specs: associations, validations, enums, kind-specific required fields.
- `GameBreakdown::Timeline` specs: a scenario per rule (speech order, tie chains, lift majority, removal cancels voting,
  result computation incl. draw, best move eligibility, each warning).
- Request specs: access (guest / user / judge / admin), toggle off → 404, CRUD of blocks.
- System spec: main editor flow (create → seats → zero round with nominations and a split → night → next day).
- Mutation testing: evilution then mutant on models and timeline.

## Delivery (sub-issues)

| # | Scope |
|---|---|
| 1 | Data model: migrations, models, validations, factories, feature toggle key |
| 2 | Timeline: alive seats, phase labels, speech order, nominations, vote round outcomes, result |
| 3 | Warnings on top of the timeline |
| 4 | Editor skeleton: index, create, header, seats, phases, "+ next phase" / delete last phase, access + toggle |
| 5 | Editor day: speeches and moves, vote rounds and votes, automatic step creation |
| 6 | Editor night: open and closed roles forms |
| 7 | Read-only view page |
| 8 | Avo resource, judge menu link, announcement |

Dependencies: 2 → 1; 3 → 2; 4 → 1; 5 → 2, 4; 6 → 2, 4; 7 → 3; 8 → 4.

## Out of scope

- Analytics (who was nominated / suspected most, check accuracy).
- Public page, export, Telegram sharing.
- Quick keyboard input for moves.
- DB-managed move types.
