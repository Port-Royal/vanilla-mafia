# Vanilla Mafia — Getting Started

## Prerequisites

```bash
# Ruby 3.3+ via mise
mise use ruby@4

# Rails 8
gem install rails

# Claude Code CLI (uses Claude Max subscription)
npm install -g @anthropic-ai/claude-code

# Beads task tracker
npm install -g @beads/bd

# SwarmSDK CLI
gem install swarm_cli
```

## Create the Project and Launch Agents

The new Rails project should be a sibling of the old PHP project:

```
personal/
├── chimafia/          # old PHP project (read-only reference)
│   ├── chimafia/      # main app (models, views, controllers, migrations)
│   ├── webix/         # admin framework extension
│   ├── library/       # base library extension
│   ├── RAILS_MIGRATION_PROMPT.md
│   └── GETTING_STARTED.md   # ← you are here
└── vanilla-mafia/    # new Rails project (created below)
```

```bash
cd ~/personal
rails new vanilla-mafia --css=tailwind --skip-jbuilder
cd vanilla-mafia
cp ../chimafia/RAILS_MIGRATION_PROMPT.md .
bd init
```

Then start the agent team:

```bash
claude-swarm
```

Give it the initial setup instruction:

```
Read RAILS_MIGRATION_PROMPT.md and execute Phase 1: install all required gems
(claude-on-rails, rspec-rails, factory_bot_rails, capybara, devise, pundit,
shoulda-matchers, simplecov, etc.), run generators (rspec:install,
claude_on_rails:swarm, devise:install), configure agent prompts from
RAILS_MIGRATION_PROMPT.md, create initial beads epics and tasks for all 4 phases,
and set up the database schema with all migrations.
```

## Working with Agents

**Start a session:**

| Mode | Command | When to use |
|------|---------|-------------|
| Agent team | `claude-swarm` | Feature work spanning multiple layers |
| Single agent | `claude` | Focused tasks, debugging, exploration |
| Pipeline | `swarm run vanilla-mafia-swarm.yml -p "..."` | Multi-stage workflows |

**Give instructions by referencing the prompt:**

```
> Implement the Hall of Fame page following RAILS_MIGRATION_PROMPT.md
  section "Public Pages" item 5. Start with the acceptance test.
```

**When agents need to reference the old project** (e.g., to understand a behavior or extract a formula), they can read files from `../chimafia/`. The paths are documented in the "Project Paths" table at the top of `RAILS_MIGRATION_PROMPT.md`.

**Track progress with beads:**

```bash
bd ready                     # see what's unblocked
bd show <id>                 # task details
bd update <id> --done        # mark completed
```

**Review what agents produced:**

```bash
bundle exec rspec            # tests pass?
bd ready                     # what's next?
```

## Quick Reference

| Action | Command |
|--------|---------|
| Start agent team | `claude-swarm` |
| Start single agent | `claude` |
| See ready tasks | `bd ready` |
| Run tests | `bundle exec rspec` |
| Check coverage | `open coverage/index.html` |
| Start Rails server | `bin/dev` |
