# service-webhook compose-manager

Operator-focused Docker Compose manager for running `service-webhook` blue/green behind Traefik. Traefik uses the file provider; changing `traefik/dynamic/active.yml` switches public traffic between `service-webhook-blue` and `service-webhook-green`.

## Files

- `docker-compose.yml` - Traefik plus blue/green app services. App containers only use `expose`; they do not publish host ports.
- `compose.build.yml` - local build override using `SERVICE_WEBHOOK_SOURCE_DIR`.
- `compose.registry.yml` - registry image/tag override.
- `traefik/traefik.yml` - static Traefik config.
- `traefik/templates/active.yml.tmpl` - dynamic route template rendered by scripts.
- `scripts/*.sh` - deploy, readiness, switch, rollback, verify, and stop helpers.
- `env/blue.env`, `env/green.env` - scheduler ownership flags managed by scripts.

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
# edit .env, including SERVICE_WEBHOOK_SOURCE_DIR
COMPOSE_MODE=build ./scripts/deploy-color.sh blue
./scripts/switch-active.sh blue
./scripts/verify-active.sh
```

### Registry image/tag

```sh
cp .env.example .env
# edit .env, including SERVICE_WEBHOOK_IMAGE and SERVICE_WEBHOOK_TAG
COMPOSE_MODE=registry ./scripts/deploy-color.sh green
./scripts/switch-active.sh green
./scripts/verify-active.sh
```

## Blue/green operator runbook

Example: blue is active, deploy green.

1. Deploy inactive color with scheduler disabled and wait for container `/readyz`:

   ```sh
   COMPOSE_MODE=registry ./scripts/deploy-color.sh green
   ```

2. Promote green. The script writes `SCHEDULER_ENABLED=true` for green and `false` for blue, recreates green, waits for `/readyz`, atomically renders/moves the Traefik dynamic config to route to green, then disables/recreates blue best-effort:

   ```sh
   ./scripts/switch-active.sh green
   ```

3. Verify Traefik public routing:

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
