# Docker LEMP — local services

This project provisions the backing services used by local development: Redis, MySQL, phpMyAdmin, SQL Server (`db-mssql`), RabbitMQ, and Mailpit for local email capture. There is no application code here — see [CLAUDE.md](../CLAUDE.md) for the full architecture notes (including the currently-disabled nginx/php-fpm setup).

# How to run #

Dependencies:

* Docker. See [https://docs.docker.com/engine/installation](https://docs.docker.com/engine/installation)
* Docker Compose (the `docker compose` plugin, bundled with Docker Desktop)

From the repo root (where `docker-compose.yml` lives):

```bash
docker compose up -d
```

This builds/pulls whatever is missing and starts **every** service in the background. Check that everything came up healthy:

```bash
docker compose ps
```

All services should show `Up` (redis, mysql, and rabbitmq also report `(healthy)` once their healthcheck passes, usually within ~30s).

## Services & ports ##

Ports below are the `.env` defaults (`${VAR:-default}` in `docker-compose.yml`) — override them in `.env` if needed.

Service|Container name|Host port|Notes
-------|--------------|---------|-----
Redis|`docker-lemp-redis`|`6379`|`redis-cli ping` → `PONG`
MySQL 8.0|`docker-lemp-mysql`|`3306`|credentials from `.env` (`DB_USERNAME`/`DB_PASSWORD`/`DB_ROOT_PASSWORD`)
phpMyAdmin|`docker-lemp-phpmyadmin`|`8080`|UI at [localhost:8080](http://localhost:8080), points at the `mysql` service
SQL Server 2022|`docker-lemp-dbmssql`|`1433`|`sa` password is `DB_ROOT_PASSWORD`; built from `./docker/mssql/`
RabbitMQ|`docker-lemp-rabbitmq`|`5672` (AMQP), `15672` (management UI)|UI at [localhost:15672](http://localhost:15672); user/pass from `RABBITMQ_USER`/`RABBITMQ_PASSWORD`, default `guest`/`guest`
Mailpit|`docker-lemp-mailpit`|`8025` (web UI), `1025` (SMTP)|UI at [localhost:8025](http://localhost:8025) for captured mail; point apps at `mailpit:1025` inside the compose network

## Starting only one service ##

```bash
docker compose up -d SERVICE_NAME
```

For example, to bring up only SQL Server:

```bash
docker compose up -d db-mssql
```

This only starts/rebuilds `db-mssql` and leaves the rest untouched — if it's already running with an unchanged config, this is a no-op. The only service with a dependency is `phpmyadmin` (`depends_on: mysql`), so `docker compose up -d phpmyadmin` will also start `mysql`; add `--no-deps` if you want phpMyAdmin alone (it just won't work until MySQL is reachable):

```bash
docker compose up -d --no-deps phpmyadmin
```

## Stopping everything ##

```bash
docker compose stop
```

Stops every container but keeps them (and all data under `docker/*/data`) in place — a plain `docker compose up -d` afterwards starts them again with no rebuild.

Other variants:

* Stop one service: `docker compose stop SERVICE_NAME`
* Restart one service: `docker compose restart SERVICE_NAME`
* Stop **and remove** the containers (data on disk under `docker/*/data` is still preserved, it's bind-mounted, not a named volume): `docker compose down`

## Logs & shells ##

```bash
docker compose logs -f SERVICE_NAME

docker compose exec redis redis-cli ping
docker compose exec mysql mysql -uroot -p"$DB_ROOT_PASSWORD"
docker compose exec db-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$DB_ROOT_PASSWORD" -No
docker compose exec rabbitmq rabbitmqctl status


docker system prune -a --volumes -f
```
