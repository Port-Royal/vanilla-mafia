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
- **JSON output**: Add `--format json` for machine-readable results
- **Custom timeout**: `--timeout 30` (default 10s)
- **CI gate**: `--min-score 0.8` exits non-zero if score is below threshold

#### Key Differences from Mutant
- Uses Prism parser (Ruby's official parser) instead of the `parser` gem
- Supports line-range targeting for fast PR-level feedback
- Structured JSON output designed for CI pipelines and AI agents
- MIT license (no commercial restrictions)

### Mutant

[Mutant](https://github.com/mbj/mutant) is an AST-based mutation testing tool.

#### Running Mutant
- **Single class**: `bundle exec mutant run -- 'YourClass'`
- **Single method**: `bundle exec mutant run -- 'YourClass#method_name'`
- **After writing tests**: Always run mutant against the class under test to verify test quality

### Workflow
1. Write or modify code
2. Write RSpec tests that pass
3. Run mutation testing against the changed class(es) to check for surviving mutants
4. If mutants survive, add or strengthen assertions to kill them
5. Aim for zero surviving mutants on all new/modified code

### Limitations
- Mutant only mutates `def` method bodies — Rails DSL (scopes, validations, associations) are not mutated
- For scopes and validations, rely on RSpec + Shoulda Matchers for coverage

### Common Surviving Mutants to Watch For
- Missing boundary/edge case assertions (e.g., `>` vs `>=`)
- Untested return values
- Conditional branches without dedicated test cases
- Method calls whose removal doesn't break any test