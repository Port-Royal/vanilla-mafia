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

Deploys are automated via GitHub Actions + [Kamal](https://kamal-deploy.org/).

**Triggering a deploy:**

```bash
git tag v0.1.0
git push origin v0.1.0
```

Pushing a `v*` tag runs CI first; if all checks pass, Kamal deploys to the production VPS.

**Required GitHub Secrets:**

| Secret | Description |
|--------|-------------|
| `SSH_PRIVATE_KEY` | Private key with access to the production VPS |
| `DEPLOY_SERVER` | Production server IP address |
| `RAILS_MASTER_KEY` | Contents of `config/master.key` |
| `REGISTRY_PASSWORD` | Classic PAT with `write:packages` scope for ghcr.io |
| `ADMIN_EMAIL` | Admin user email (used by `db:seed`) |
| `ADMIN_PASSWORD` | Admin user password (used by `db:seed`, only on first run) |

**Manual deploy** (from a local machine):

```bash
export DEPLOY_SERVER=<server-ip>
export ADMIN_EMAIL=admin@example.com
export ADMIN_PASSWORD=<password>
bin/kamal deploy
```

Requires `gh` CLI authenticated (with `write:packages` scope) and `config/master.key` present locally.
