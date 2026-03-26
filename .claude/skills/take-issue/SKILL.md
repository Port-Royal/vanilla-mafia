---
name: take-issue
description: Take an issue end-to-end — claim it, analyze, write failing tests (TDD), implement, run mutation testing, commit, push, and create a PR
argument-hint: "<beads-id or gh-number>"
user-invocable: true
disable-model-invocation: true
---

# Take Issue

Full end-to-end workflow: claim an issue, analyze it, write failing tests, implement, run mutation testing, commit, push, and create a PR.

## Arguments

All arguments are passed as `$ARGUMENTS`. Accept either:
- A beads issue ID: `vanilla-mafia-218`
- A GitHub issue number: `471` or `gh-471`

Examples:
```
/take-issue vanilla-mafia-218
/take-issue 471
```

## Phase 1: Resolve & Claim Issue

1. **Resolve the identifier to both beads ID and GitHub number**:
   - If argument looks like `vanilla-mafia-*`: run `bd show <id>`, extract `External: gh-<number>`.
   - If argument is a number or `gh-<number>`: search beads for the matching external-ref with `bd list --status=open`, find the issue with that external-ref. If no beads issue exists, create one using `/create-issue`.

2. **Show issue details** from both systems:
   ```
   bd show <beads-id>
   gh issue view <gh-number> --repo Port-Royal/vanilla-mafia --json title,body,labels,state
   ```

3. **Mark as in-progress**:
   ```
   bd update <beads-id> --status=in_progress
   ```

## Phase 2: Branch Setup

4. **Check the current branch** with `git status`:
   - If current branch matches `<beads-id>` (e.g., `vanilla-mafia-218`) or follows a GitHub-created pattern for this issue — **use it as-is**, just run `git pull` to sync.
   - Otherwise — checkout master, pull, and create a new branch:
     ```
     git checkout master && git pull
     git checkout -b <beads-id> master
     ```

## Phase 3: Analyze & Clarify

5. **Analyze the issue description** from both beads and GitHub. Consider:
   - Is the problem/feature clearly defined?
   - Are acceptance criteria specified or can they be inferred?
   - Are there edge cases or ambiguities?
   - What files/models/controllers are likely involved?

6. **If anything is unclear — ASK the user** before proceeding. Do not guess at requirements. Present specific questions about the ambiguities found.

7. **Build acceptance requirements** — a clear list of what "done" means for this issue. Present them to the user for confirmation before writing tests.

## Phase 4: TDD — Write Failing Tests First

8. **Write RSpec tests** covering the acceptance requirements. Tests MUST include:
   - Happy path scenarios
   - Corner/edge cases
   - Invalid argument handling
   - Failure scenarios

   Follow project conventions:
   - Use `let_it_be`/`let`/`let!` declarations and nested `context` blocks
   - Use `context` blocks to group scenarios (e.g., `context "when input is nil"`)
   - Do NOT declare variables inside `it` blocks
   - Keep `it` blocks focused on expectations only

9. **Run the tests — they MUST all fail** (red phase). If any test passes before implementation, it is not testing new behavior — fix or remove it.

## Phase 5: Implement

10. **Write the simplest implementation** that makes all tests pass. Rules:
    - Do not overengineer. Simplest solution wins.
    - Follow rubocop rules. Run `bundle exec rubocop` on changed files.
    - If changes cause rubocop class-size, method-size, or complexity violations that cannot be reasonably fixed in scope, add a rubocop exclusion AND immediately create a tech debt issue:
      ```
      /create-issue --title "Tech debt: refactor <class/method>" --description "Rubocop <cop-name> exclusion added in <beads-id>. Refactor to comply." --type task --priority 3
      ```
    - Use existing scopes, helpers, and i18n — check before writing raw queries or hardcoded strings.
    - No `&.` safe navigation — trust framework guarantees.

11. **Run tests — they MUST all pass** (green phase).

## Phase 6: Mutation Testing

12. **Run mutant first** on each changed class/method:
    ```
    bundle exec mutant run --jobs 4 -- 'ClassName'
    ```

13. **Run evilution second** via MCP tool or CLI on each changed file:
    ```
    bundle exec evilution run <file> --format json --jobs 4 --spec <spec-file>
    ```

14. **Compare results** from both tools.

15. **Kill surviving mutants** — improve tests until no real (non-equivalent) mutants survive.

16. **Append detailed feedback** to `.artifacts.local/regular-evilution-feedback.log`:
    ```
    ### <date> — <ClassName> (<file path>)
    **Evilution version:** <version>
    **Results:**
    - Mutant: X% (Y/Z killed)
    - Evilution: X% (Y/Z killed)
    **What mutant does better:** <specifics>
    **What evilution does well:** <specifics>
    **What could make evilution greater:** <suggestions>
    ```

## Phase 7: Commit, Push & PR

17. **Run rubocop** one final time on all changed files. Fix any offenses.

18. **Run specs** one final time to confirm everything passes.

19. **Commit** with a descriptive message referencing the beads ID:
    ```
    git add <specific-files>
    git commit -m "<beads-number>: <summary>

    <details if needed>

    Closes #<gh-number>

    - Mutant: X% (Y/Z killed)
    - Evilution: X% (Y/Z killed)

    Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
    ```
    IMPORTANT: Get the correct GH number from `bd show <beads-id>` → `External: gh-NNN`.

20. **Push and create PR**:
    ```
    git push -u origin <beads-id>
    gh pr create --repo Port-Royal/vanilla-mafia --title "<beads-number>: <title>" --body "..."
    ```
    PR body format:
    ```
    ## Summary
    <bullet points>

    ## Mutation Testing
    - Mutant: X% (Y/Z killed)
    - Evilution: X% (Y/Z killed)

    Closes #<gh-number>

    ## Test plan
    <checklist>

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    ```

21. **Assign the PR** to `@marinazzio`:
    ```
    gh api repos/Port-Royal/vanilla-mafia/issues/<pr-number> --method PATCH -f "assignees[]=marinazzio"
    ```

22. **Close the beads issue and sync**:
    ```
    bd close <beads-id>
    bd sync
    ```
