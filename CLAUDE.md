# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A Docker Compose environment (not an application codebase) that provisions the backing services for one or more externally-hosted PHP applications ("hibes"/"admin"/"chat", referenced in `.vscode/settings.json` and `docker/release.sh` but not present in this repo). There is no application source code here — only Dockerfiles, compose config, and DB bootstrap scripts.

## Common commands

All compose commands must be run from the repo root (where `docker-compose.yml` lives). See [docker/README.md](docker/README.md) for the full walkthrough (ports, per-service start/stop, health checks).

```bash
# Start everything (uses root .env automatically)
docker compose up -d

# Start only specific services
docker compose up --no-deps redis phpmyadmin mysql

# Rebuild and restart (mirrors docker/release.sh, but using ./docker/.env explicitly)
docker compose --env-file ./docker/.env build
docker compose --env-file ./docker/.env up -d

# Tear down
docker compose down

# Logs / shells
docker compose logs SERVICE_NAME
docker compose exec mysql mysql -uroot -p"$DB_ROOT_PASSWORD"
docker compose exec db-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD"
```

`docker/release.sh` is the production deploy script (run on the server as the `deploy` user): it sources `docker/.env`, force-removes the named containers, then rebuilds and brings everything back up. It is not meant to be run casually from a dev machine.

## Architecture

### Services (`docker-compose.yml`)

Only backing services are currently active:
- `redis` — cache, healthchecked via `redis-cli ping`.
- `mysql` (8.0) — primary app database; seeded from `docker/mysql/initdb/` (gitignored, populated locally) and persists to `docker/mysql/data/` (gitignored).
- `phpmyadmin` — UI for the `mysql` service.
- `db-mssql` — SQL Server 2022, built from `./docker/mssql/` (its own Dockerfile/entrypoint, see below).
- `rabbitmq` — general-purpose local broker (`rabbitmq:3-management-alpine`), management UI on `RABBITMQ_MGMT_PORT` (default `15672`), credentials via `RABBITMQ_USER`/`RABBITMQ_PASSWORD` (default `guest`/`guest`); persists to `docker/rabbitmq/data/` (gitignored).

`docker/nginx/nginx.conf` and `docker/php-fpm/Dockerfile.9001` (PHP 8.3-FPM with yaz, redis, imagick, and the common Laravel-oriented extensions, listening on port 9001) are kept for an nginx+php-fpm setup that is not currently wired into `docker-compose.yml`. To re-enable it, add `webserver`/`php-fpm-9001` services with the app code mounted at `./symlink_app1` (currently an empty placeholder directory meant to hold a symlink to the real app checkout — see the `ln -s ...` example in `docker/release.sh`), nginx routing PHP requests to `php-fpm-9001:9001`.

### Two `.env` files, two different roles

- Root `.env` — used implicitly by plain `docker compose` invocations; **untracked** (matches `git status`).
- `docker/.env` — used explicitly by `docker/release.sh` and by the `--env-file ./docker/.env` commands above; **this one is committed to git** (`docker/.env` is tracked, unlike `.gitignore` might suggest). Both currently hold live-looking DB credentials. Treat any edits here as touching checked-in secrets, not local-only config.

### `db-mssql` bootstrap flow (`docker/mssql/`)

`Dockerfile` builds from `mcr.microsoft.com/mssql/server:2022-latest` and sets `ENTRYPOINT ["./entrypoint.sh"]`. `entrypoint.sh` backgrounds `configure-db.sh` and then execs `sqlservr` in the foreground. `configure-db.sh` polls `sqlcmd` until SQL Server reports all databases online, then either backs up the existing `ferah` database or creates+restores it from `/var/opt/mssql/data/backup.bak` if it doesn't exist yet.

In practice, `/var/opt/mssql/data` (including `master.mdf`) is a bind-mounted, persistent volume (`docker/mysql/data/` equivalent for mssql), so SQL Server re-attaches all previously known databases on every container start regardless of this script — the create/restore branch only matters for a genuinely empty data directory (which requires a `backup.bak` to already be present there; none is checked into this repo).
