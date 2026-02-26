# Vanilla Mafia

A web application for tracking Mafia game results, player ratings, and awards.

## Requirements

- Ruby 4.0.1
- Rails 8.1.2
- SQLite 3

## Setup

```bash
bundle install
bin/rails db:prepare
```

### Seeding the database

Roles are always seeded. To also create an admin user, provide credentials via environment variables:

```bash
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=your_secure_password bin/rails db:seed
```

## Running tests

```bash
bundle exec rspec
```

### Mutation testing

```bash
bundle exec mutant run -- 'ClassName'
```

## Deployment

The app is deployed with [Kamal](https://kamal-deploy.org/) using [ghcr.io](https://ghcr.io) as the container registry.

### Prerequisites

- [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`)
- SSH access to the production server
- `config/master.key` present locally (not checked into git)

### Deploying

```bash
bin/kamal deploy
```

### Environment variables

Kamal injects these into the production container (configured in `config/deploy.yml` and `.kamal/secrets`):

| Variable | Description |
|----------|-------------|
| `RAILS_MASTER_KEY` | Encryption key for credentials (read from `config/master.key`) |
| `KAMAL_REGISTRY_PASSWORD` | ghcr.io auth token (read from GitHub CLI) |

Set the following environment variables when seeding the database for the first time:

| Variable | Description |
|----------|-------------|
| `ADMIN_EMAIL` | Admin user email (used by `db:seed`) |
| `ADMIN_PASSWORD` | Admin user password (used by `db:seed`, only on first run) |
