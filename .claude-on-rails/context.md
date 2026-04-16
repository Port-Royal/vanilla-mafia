# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Project Information
- **Rails Version**: 8.1.2
- **Ruby Version**: 4.0.1
- **Project Type**: Full-stack Rails
- **Test Framework**: RSpec
- **Turbo/Stimulus**: Enabled

## Swarm Configuration

The claude-swarm.yml file defines specialized agents for different aspects of Rails development:
- Each agent has specific expertise and works in designated directories
- Agents collaborate to implement features across all layers
- The architect agent coordinates the team

## Development Guidelines

When working on this project:
- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries

### RSpec Style

Write specs using `let_it_be`/`let`/`let!` declarations and nested `context` blocks:
- Prefer `let_it_be` (from test-prof) over `let!` for test data that does not need to be recreated per example — this creates records once per describe/context group
- Use `let!` only when records are redefined in nested contexts or mutated by examples
- Use `context` blocks to group scenarios (e.g., `context "when games_count is zero"`)
- Do **not** declare variables inside `it` blocks — use `let` instead
- Keep `it` blocks focused on expectations only

## Mutation Testing

This project uses two mutation testing tools:

### Evilution

[Evilution](https://github.com/marinazzio/evilution) is a Prism-based mutation testing tool with structured JSON output.

#### Running Evilution
- **Single file**: `bundle exec evilution run app/models/your_model.rb`
- **Line range**: `bundle exec evilution run app/models/your_model.rb:15-30`
- **Specific method**: `bundle exec evilution run app/models/your_model.rb --target YourClass#method_name`
- **Parallel execution**: `--jobs N` or `-j N` for parallel mutation testing (e.g., `-j 4`)
- **JSON output**: Add `--format json` for machine-readable results
- **Custom timeout**: `--timeout 30` (default 30s)
- **CI gate**: `--min-score 0.8` exits non-zero if score is below threshold
- **Fail fast**: `--fail-fast` stops after first surviving mutant (or `--fail-fast=N` for N survivors)
- **Override spec**: `--spec spec/models/foo_spec.rb` to override auto-detected spec file

#### Additional Options (0.18.0)
- **Incremental mode**: `--incremental` caches killed/timeout results, skips re-running on unchanged files
- **Isolation strategy**: `--isolation auto|fork|in_process` (default: auto)
- **Test suggestions**: `--suggest-tests` generates concrete RSpec test code for surviving mutants
- **Sessions**: `--save-session` saves results; `session list|show|diff|gc` to manage
- **Baseline comparison**: `--baseline-session PATH` compares against a prior session in HTML report
- **HTML output**: `--format html` for visual reports
- **Disable comments**: `# evilution:disable` in source; `--show-disabled` to report skipped mutations
- **Stdin targets**: `--stdin` reads target file paths from stdin
- **Extended targeting**: `--target descendants:Foo`, `--target source:**/*.rb`, `--target Foo*`

#### Inspection Commands (no mutation run needed)
- **List subjects**: `bundle exec evilution subjects app/models/foo.rb` — shows all mutation subjects (methods), line numbers, and mutation counts
- **List test mappings**: `bundle exec evilution tests list app/models/foo.rb` — shows auto-detected spec file for each source
- **Preview mutations**: `bundle exec evilution util mutation -e 'def foo; x > 0; end'` — preview mutations for a code snippet without running tests
- **Show environment**: `bundle exec evilution environment show` — display current settings, config file, and versions

#### MCP Integration
Evilution ships an MCP server (`evilution mcp`) with 4 tools:
- **evilution-mutate**: Run mutations with `verbosity` (full/summary/minimal) and `suggest_tests` params
- **evilution-session-list**: List past sessions with `--limit` and `--results-dir`
- **evilution-session-show**: Show full session details including survived mutation diffs
- **evilution-session-diff**: Compare two sessions — shows regressions, fixes, and persistent survivors

#### Additional CLI Flags
- **Skip heredoc literals**: `--skip-heredoc-literals` — skip string literal mutations inside heredocs
- **No progress bar**: `--no-progress` — disable progress bar (useful for CI/scripting)
- **Custom results dir**: `--results-dir DIR` — override session results directory
- **Session filtering**: `--since DATE` (YYYY-MM-DD), `--older-than DURATION` (e.g., 30d, 1w), `--limit N`
- **Fallback to full suite**: `--fallback-full-suite` (0.24.0) — when a mutation has no resolved spec, run the whole suite instead of marking it `:unresolved` and skipping (opt-in; default behavior remains fast-skip)
- **Related specs heuristic**: `--related-specs-heuristic` — append related request/integration/feature/system specs for `includes()` mutations
- **Parent-process preload**: `--preload FILE` / `--no-preload` (0.22.2) — preload a file (e.g. `spec/rails_helper.rb`) in the parent process so forked children inherit the loaded framework via copy-on-write; auto-detects `spec/rails_helper.rb` on Rails projects

#### Rails Behavior (0.22.2+)
- **Auto fork isolation on Rails**: `--isolation auto` (default) detects Rails projects and resolves to `fork` instead of `in_process` — avoids indefinite hangs caused by Rails' `Thread.handle_interrupt(Exception => :never)` masking `Timeout.timeout`. Explicit `--isolation in_process` on a Rails project emits a warning.
- **Zero-boot mutations**: parent-process preload of `spec/rails_helper.rb` is automatic; children inherit via copy-on-write. Disable with `--no-preload` if needed.

#### Compatibility Fixes Worth Knowing (0.22.1 → 0.24.0)
- **Rails 8 `enum` models** (0.22.7): constants are now dropped before re-loading a mutated file, so `detect_enum_conflict!` no longer errors every mutation.
- **`ActiveSupport::Concern`** (0.22.5): `MultipleIncludedBlocks` errors on mutated concerns are fixed.
- **Zeitwerk re-autoload** (0.22.6): autoloader no longer re-triggers during mutation load.
- **`require_relative` in mutated files** (0.24.0): now resolves against the real source tree (previously broken by the temp-dir copy strategy).
- **`spec_helper` LoadError** (0.22.3 / 0.22.4): projects with `--require spec_helper` in `.rspec` no longer fail on every mutation.
- **Multi-byte characters** (0.22.0): Prism byte offsets now use `byteslice` — Cyrillic / CJK source files are no longer garbled. Relevant since this project contains Russian strings.
- **Error diagnostics** (0.22.1): `--verbose` now logs error class + backtrace; JSON output includes `error_class` / `error_backtrace` under `errors[]`.

#### New Operators Since 0.18.0
- **0.22.0**: `index_to_at` (`arr[0]` → `arr.at(0)`), `regex_simplification`, `block_pass_removal`
- **0.20.0**: `loop_flip`, `string_interpolation`, `retry_removal`, `case_when`, `predicate_replacement`, `equality_to_identity`, `lambda_body`, `begin_unwrap`, `block_param_removal`, plus `downcase`↔`upcase`, `strip`/`lstrip`/`rstrip`, `chomp`↔`chop` swap pairs
- Total operators: **72** (up from 60)

#### Minitest Support (0.22.0)
Full Minitest integration via `--integration minitest` / `integration: minitest` config option. RSpec remains the default and the framework used by this project.

#### Key Differences from Mutant
- Uses Prism parser (Ruby's official parser) instead of the `parser` gem
- Supports line-range targeting for fast PR-level feedback
- Per-mutation spec targeting — automatically resolves matching spec file for each source file
- Structured JSON output designed for CI pipelines and AI agents
- MIT license (no commercial restrictions)

### Mutant

[Mutant](https://github.com/mbj/mutant) is an AST-based mutation testing tool.

#### Running Mutant
- **Single class**: `bundle exec mutant run --jobs 1 -- 'YourClass'`
- **Single method**: `bundle exec mutant run --jobs 1 -- 'YourClass#method_name'`
- **After writing tests**: Always run mutant against the class under test to verify test quality

### Workflow
1. Write or modify code
2. Write RSpec tests that pass
3. Run **evilution first** (via MCP tool or CLI) against the changed file(s) — fix any surviving mutants
4. Run **mutant second** against the changed class(es) — fix any additional surviving mutants
5. Compare results from both tools and append detailed feedback to `.artifacts.local/regular-evilution-feedback.log`
6. In the PR description, note mutation testing results from both tools (evilution listed first)
7. Aim for zero surviving mutants on all new/modified code

### Data Collection (Mutant vs Evilution)

In every PR, include mutation scores in the description:
```
- Evilution: X% (Y/Z mutants killed)
- Mutant: X% (Y/Z mutants killed)
```

After each mutation testing run, append a detailed entry to `.artifacts.local/regular-evilution-feedback.log` including:
- Evilution version (from `bundle exec evilution --version` or gem lockfile)
- What mutant does better (operators, precision, equivalent mutant detection)
- What evilution is missing or could improve
- Suggestions for making evilution greater

### Limitations
- Mutant only mutates `def` method bodies — Rails DSL (scopes, validations, associations) are not mutated
- Evilution mutates at the file level including DSL code, but may generate different mutation operators
- For scopes and validations, rely on RSpec + Shoulda Matchers for coverage

### Common Surviving Mutants to Watch For
- Missing boundary/edge case assertions (e.g., `>` vs `>=`)
- Untested return values
- Conditional branches without dedicated test cases
- Method calls whose removal doesn't break any test