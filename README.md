# service-webhook compose-manager

Operator-focused Docker Compose manager for running multi-brand `service-webhook` APIs behind Traefik with blue/green deployment. Each brand (Verixa, Lgpay) gets its own blue/green pair and independent Traefik routing. Traefik uses the file provider; changing `traefik/dynamic/active.yml` atomically switches public traffic for all brands between blue and green.

## Architecture

### Multi-brand blue/green

| Brand   | Blue service      | Green service      | Port  | DB              | Traefik host rule               |
|---------|-------------------|--------------------|-------|-----------------|---------------------------------|
| Verixa  | `api-verixa-blue` | `api-verixa-green` | 8900  | `verixa_prod`   | `Host($SERVICE_WEBHOOK_HOST)`   |
| Lgpay   | `api-lgpay-blue`  | `api-lgpay-green`  | 8902  | `lgpay_prod`    | `Host($LGPAY_WEBHOOK_HOST)`    |

- **Phase 1 = atomic color switch**: deploying "blue" means all brand APIs go blue together. Per-brand switching is a future enhancement.
- **Sandbox** is NOT managed here — it runs as a single instance in the service-webhook repo (no blue/green needed).
- **Cron containers** are NOT managed here — they stay in the service-webhook repo. Compose-manager only manages API services behind Traefik.
- App containers use `expose` (not `ports`); Traefik handles external routing.

### Redis

A local `redis:7-alpine` service with healthcheck is included. MySQL is external on the shared network.

## Files

- `docker-compose.yml` — Traefik, Redis, and per-brand blue/green API services. Uses YAML anchors (`x-api-verixa-common`, `x-api-lgpay-common`) to DRY blue/green pairs.
- `compose.build.yml` — local build override for all brand services.
- `compose.registry.yml` — registry image/tag override for all brand services.
- `traefik/traefik.yml` — static Traefik config.
- `traefik/templates/active.yml.tmpl` — dynamic route template rendered by scripts. Contains per-brand routers and weighted services.
- `scripts/*.sh` — deploy, readiness, switch, rollback, verify, and stop helpers.
- `env/blue.env`, `env/green.env` — scheduler ownership flags managed by scripts (tracked in git; contain only `SCHEDULER_ENABLED`).

## Prerequisites

1. Copy `.env.example` to `.env` and replace placeholders. Do not commit `.env`.
2. Ensure the shared external network exists and can reach dependencies such as MySQL/Redis/Laravel:

   ```sh
   docker network create shared
   ```

   Or set `SHARED_NETWORK_NAME` in `.env` to an existing Docker network.
3. Ensure `service-webhook` has unauthenticated `GET /readyz`; scripts use it for promotion checks.

## Workflows

Set `COMPOSE_MODE=build` for local source builds or `COMPOSE_MODE=registry` for image pulls. The scripts default to registry mode.

### Local build

```sh
cp .env.example .env
# edit .env, including SERVICE_WEBHOOK_PATH and brand host rules
COMPOSE_MODE=build ./scripts/deploy-color.sh blue
./scripts/switch-active.sh blue
./scripts/verify-active.sh
```

### Registry image/tag

```sh
cp .env.example .env
# edit .env, including SERVICE_WEBHOOK_IMAGE, SERVICE_WEBHOOK_VERSION, and brand host rules
COMPOSE_MODE=registry ./scripts/deploy-color.sh green
./scripts/switch-active.sh green
./scripts/verify-active.sh
```

## Blue/green operator runbook

Example: blue is active, deploy green.

1. Deploy inactive color with scheduler disabled and wait for all brand containers' `/readyz`:

   ```sh
   COMPOSE_MODE=registry ./scripts/deploy-color.sh green
   ```

2. Promote green. The script writes `SCHEDULER_ENABLED=true` for green and `false` for blue, recreates all green brand containers, waits for `/readyz`, atomically renders/moves the Traefik dynamic config to route all brands to green, then disables/recreates blue containers best-effort:

   ```sh
   ./scripts/switch-active.sh green
   ```

3. Verify Traefik public routing for all brands:

   ```sh
   ./scripts/verify-active.sh
   ```

4. Roll back if needed:

   ```sh
   ./scripts/rollback.sh blue
   ./scripts/verify-active.sh
   ```

5. Stop old color after confidence:

   ```sh
   ./scripts/stop-color.sh blue
   ```

## Scheduler safety

The intended design is single scheduler ownership. `env/blue.env` and `env/green.env` contain only `SCHEDULER_ENABLED=true|false`; scripts manage these files and recreate containers when ownership changes. Keep the inactive color at `SCHEDULER_ENABLED=false`. If the application build does not yet implement `SCHEDULER_ENABLED`, do not run both colors against the same settlement data until that flag is available, or use an application/distributed lock that prevents duplicate scheduler execution.

## Manual compose commands

Render an initial route if you are not using scripts:

```sh
./scripts/switch-active.sh blue
```

Inspect Compose output:

```sh
docker compose --env-file .env.example -f docker-compose.yml -f compose.build.yml config
docker compose --env-file .env.example -f docker-compose.yml -f compose.registry.yml config
```

## Environment variables

| Variable                            | Default                          | Description                                    |
|-------------------------------------|----------------------------------|------------------------------------------------|
| `COMPOSE_PROJECT_NAME`              | `service-webhook-bg`             | Docker Compose project name                    |
| `TRAEFIK_HTTP_PORT`                 | `80`                             | Traefik public HTTP port                       |
| `TRAEFIK_DASHBOARD_PORT`            | `8080`                           | Traefik dashboard port                         |
| `SERVICE_WEBHOOK_HOST`              | `webhook.example.test`           | Traefik Host rule for Verixa brand             |
| `LGPAY_WEBHOOK_HOST`                | `lgpay-webhook.example.test`     | Traefik Host rule for Lgpay brand              |
| `VERIXA_PORT`                       | `8900`                           | Internal port for Verixa API services          |
| `LGPAY_PORT`                        | `8902`                           | Internal port for Lgpay API services           |
| `VERIXA_DB_NAME`                    | `verixa_prod`                    | Database name for Verixa                       |
| `LGPAY_DB_NAME`                     | `lgpay_prod`                     | Database name for Lgpay                        |
| `VERIXA_INTERNAL_TRANSFER_BASE_URL` | `http://verixa-org-web:8000`     | Internal transfer URL for Verixa               |
| `LGPAY_INTERNAL_TRANSFER_BASE_URL`  | `http://lgpay-web:8000`          | Internal transfer URL for Lgpay                |
| `VERIXA_BLUE_INTERNAL_TRANSFER_BASE_URL` | `http://verixa-org-web-blue:8000` | Internal transfer URL for Verixa blue      |
| `LGPAY_BLUE_INTERNAL_TRANSFER_BASE_URL`  | `http://lgpay-web-blue:8000`      | Internal transfer URL for Lgpay blue       |
| `DB_HOST`                           | `mysql`                          | Shared database host                           |
| `DB_PORT`                           | `3306`                           | Shared database port                           |
| `REDIS_ADDR`                        | `redis:6379`                     | Redis address                                  |
| `SERVICE_WEBHOOK_PATH`              | `../verixa-code/service-webhook` | Source path for build mode                     |
| `SERVICE_WEBHOOK_IMAGE`             | —                                | Registry image for registry mode               |
| `SERVICE_WEBHOOK_VERSION`           | `latest`                         | Image tag/version                              |
