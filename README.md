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

Set the following environment variables in production:

| Variable | Description |
|----------|-------------|
| `ADMIN_EMAIL` | Admin user email (used by `db:seed`) |
| `ADMIN_PASSWORD` | Admin user password (used by `db:seed`, only on first run) |
