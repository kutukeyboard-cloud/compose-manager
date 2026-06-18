# service-webhook compose-manager

Operator-focused Docker Compose manager for running multi-brand `service-webhook` APIs behind Traefik with blue/green deployment. Each brand (Verixa, Lgpay, Sandbox) gets its own blue/green pair and independent Traefik port. Traefik uses the file provider; changing `traefik/dynamic/active.yml` atomically switches public traffic for all brands between blue and green.

## Architecture

### Multi-brand blue/green

| Brand   | Blue service        | Green service        | App port | Public Traefik port |
|---------|---------------------|----------------------|----------|---------------------|
| Verixa  | `api-verixa-blue`   | `api-verixa-green`   | 8900     | 8900                |
| Lgpay   | `api-lgpay-blue`    | `api-lgpay-green`    | 8902     | 8902                |
| Sandbox | `api-sandbox-blue`  | `api-sandbox-green`  | 8904     | 8904                |

- **Phase 1 = atomic color switch**: deploying "blue" means all brand APIs go blue together. Per-brand switching is a future enhancement.
- **Cron containers** are NOT managed here — they stay in the service-webhook repo. Compose-manager only manages API services behind Traefik.
- **Schedulers are disabled here** with `SCHEDULER_ENABLED=false`; scheduler ownership stays outside compose-manager.
- App containers use `expose` (not `ports`); Traefik handles external routing.
- Public routing is port-based, not hostname-based. No DNS or `/etc/hosts` entry is required.

### Public access

After an active color is selected, call each brand through the VPS host/IP and its Traefik port:

```sh
curl http://127.0.0.1:8900/readyz  # Verixa
curl http://127.0.0.1:8902/readyz  # Lgpay
curl http://127.0.0.1:8904/readyz  # Sandbox
```

From another machine on the same network, replace `127.0.0.1` with the VPS IP:

```sh
curl http://<vps-ip>:8900/readyz  # Verixa
curl http://<vps-ip>:8902/readyz  # Lgpay
curl http://<vps-ip>:8904/readyz  # Sandbox
```

### External dependencies

Redis, MySQL, Laravel, and other app dependencies are external services on the shared Docker network. Compose-manager does not include them and does not own their runtime settings. Keep app configuration such as DB credentials, Redis settings, internal transfer URLs, logging, and request timeouts in the service-webhook env files referenced by `VERIXA_APP_ENV_FILE`, `LGPAY_APP_ENV_FILE`, and `SANDBOX_APP_ENV_FILE`.

## Files

- `docker-compose.yml` — Traefik and per-brand blue/green API services. Uses YAML anchors (`x-api-verixa-common`, `x-api-lgpay-common`) to DRY blue/green pairs.
- `compose.build.yml` — local build override for all brand services.
- `compose.registry.yml` — registry image/tag override for all brand services.
- `traefik/traefik.yml` — static Traefik config.
- `traefik/templates/active.yml.tmpl` — dynamic route template rendered by scripts. Contains per-brand routers and weighted services.
- `scripts/*.sh` — deploy, readiness, switch, rollback, verify, and stop helpers.

## Prerequisites

1. Copy `.env.example` to `.env` and replace deployment placeholders. Do not commit `.env`.
2. Set `VERIXA_APP_ENV_FILE`, `LGPAY_APP_ENV_FILE`, and `SANDBOX_APP_ENV_FILE` to service-webhook runtime env files for each brand. These files should contain app config such as DB, Redis, `APP_NAME`, and internal transfer settings.
3. Ensure the shared external network exists and can reach dependencies such as MySQL/Redis/Laravel:

   ```sh
   docker network create shared
   ```

   Or set `SHARED_NETWORK_NAME` in `.env` to an existing Docker network.
4. Ensure `service-webhook` has unauthenticated `GET /readyz`; scripts use it for promotion checks.
5. Ensure the configured public ports are available on the VPS. Defaults are `8900` for Verixa, `8902` for Lgpay, `8904` for Sandbox, and `8999` for the Traefik dashboard.

## Workflows

Set `COMPOSE_MODE=build` for local source builds or `COMPOSE_MODE=registry` for image pulls. The scripts default to registry mode.

### Make targets

The `Makefile` wraps the same scripts for all-brand workflows and uses the same Compose files for targeted service workflows.

```sh
make config MODE=registry
make deploy COLOR=green MODE=registry VERSION=v1.2.3
make deploy-service SERVICE=api-sandbox COLOR=green MODE=registry VERSION=v1.2.3
make switch COLOR=green
make verify
make readyz-service SERVICE=api-sandbox COLOR=green
make rollback COLOR=blue
make stop COLOR=blue
make stop-service SERVICE=api-sandbox COLOR=blue
```

Use `VERSION=...` to override `SERVICE_WEBHOOK_VERSION` for one command without editing `.env`. Use `IMAGE=...` the same way for `SERVICE_WEBHOOK_IMAGE`.
Use `SERVICE=api-verixa`, `SERVICE=api-lgpay`, or `SERVICE=api-sandbox` with `*-service` targets to operate on one color-specific service without deploying all brands.

For example, deploy only sandbox green from registry tag `v1.0.0`:

```sh
make deploy-service SERVICE=api-sandbox COLOR=green MODE=registry VERSION=v1.0.0
make readyz-service SERVICE=api-sandbox COLOR=green
```

### Local build

```sh
cp .env.example .env
# edit .env, including SERVICE_WEBHOOK_PATH, app env file paths, and public ports if needed
COMPOSE_MODE=build ./scripts/deploy-color.sh blue
./scripts/switch-active.sh blue
./scripts/verify-active.sh
```

### Registry image/tag

```sh
cp .env.example .env
# edit .env, including SERVICE_WEBHOOK_IMAGE, SERVICE_WEBHOOK_VERSION, app env file paths, and public ports if needed
COMPOSE_MODE=registry ./scripts/deploy-color.sh green
./scripts/switch-active.sh green
./scripts/verify-active.sh
```

## Blue/green operator runbook

Example: blue is active, deploy green.

1. Deploy inactive API color and wait for all brand containers' `/readyz`:

   ```sh
   COMPOSE_MODE=registry ./scripts/deploy-color.sh green
   ```

2. Promote green. The script recreates all green brand containers, waits for `/readyz`, then atomically renders/moves the Traefik dynamic config to route all brands to green:

   ```sh
   ./scripts/switch-active.sh green
   ```

3. Verify Traefik public routing for all brands:

   ```sh
   ./scripts/verify-active.sh
   ```

   By default this checks `http://127.0.0.1:8900/readyz`, `http://127.0.0.1:8902/readyz`, and `http://127.0.0.1:8904/readyz`. Override `VERIXA_VERIFY_URL`, `LGPAY_VERIFY_URL`, or `SANDBOX_VERIFY_URL` if verification must use another address.

4. Roll back if needed:

   ```sh
   ./scripts/rollback.sh blue
   ./scripts/verify-active.sh
   ```

5. Stop old color after confidence:

   ```sh
   ./scripts/stop-color.sh blue
   ```

## API-only scope

Compose-manager deploys only the `service-webhook` API containers required for blue/green public traffic. It does not deploy cron, scheduler, Redis, MySQL, or Laravel containers. API containers are started with `SCHEDULER_ENABLED=false` so scheduler ownership remains in the service-webhook deployment layer.

This repository owns zero-downtime deployment mechanics only:

- image/build selection
- blue/green API containers
- app ports used for health checks and Traefik backends
- public Traefik ports
- `DEPLOY_COLOR`
- `SCHEDULER_ENABLED=false`

Brand-specific runtime configuration is loaded from external service-webhook env files via `VERIXA_APP_ENV_FILE`, `LGPAY_APP_ENV_FILE`, and `SANDBOX_APP_ENV_FILE`.

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
| `VERIXA_TRAEFIK_PORT`               | `8900`                           | Verixa public Traefik port                     |
| `LGPAY_TRAEFIK_PORT`                | `8902`                           | Lgpay public Traefik port                      |
| `SANDBOX_TRAEFIK_PORT`              | `8904`                           | Sandbox public Traefik port                    |
| `TRAEFIK_DASHBOARD_PORT`            | `8999`                           | Traefik dashboard port                         |
| `VERIXA_PORT`                       | `8900`                           | Internal port for Verixa API services          |
| `LGPAY_PORT`                        | `8902`                           | Internal port for Lgpay API services           |
| `SANDBOX_PORT`                      | `8904`                           | Internal port for Sandbox API services         |
| `VERIXA_APP_ENV_FILE`               | `/dev/null`                      | External service-webhook env file for Verixa   |
| `LGPAY_APP_ENV_FILE`                | `/dev/null`                      | External service-webhook env file for Lgpay    |
| `SANDBOX_APP_ENV_FILE`              | `/dev/null`                      | External service-webhook env file for Sandbox  |
| `SERVICE_WEBHOOK_PATH`              | `../verixa-code/service-webhook` | Source path for build mode                     |
| `SERVICE_WEBHOOK_IMAGE`             | `service-webhook`                | Image name for build or registry mode          |
| `SERVICE_WEBHOOK_VERSION`           | `latest`                         | Image tag/version                              |
