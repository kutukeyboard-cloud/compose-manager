#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
DYNAMIC_TEMPLATE="$ROOT_DIR/traefik/templates/active.yml.tmpl"
DYNAMIC_ACTIVE="$ROOT_DIR/traefik/dynamic/active.yml"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

APP_PORT=${APP_PORT:-8080}
SERVICE_WEBHOOK_HOST=${SERVICE_WEBHOOK_HOST:-webhook.example.test}
COMPOSE_MODE=${COMPOSE_MODE:-registry}

compose_files=("-f" "$ROOT_DIR/docker-compose.yml")
case "$COMPOSE_MODE" in
  build) compose_files+=("-f" "$ROOT_DIR/compose.build.yml") ;;
  registry) compose_files+=("-f" "$ROOT_DIR/compose.registry.yml") ;;
  *) echo "Unsupported COMPOSE_MODE=$COMPOSE_MODE (use build or registry)" >&2; exit 2 ;;
esac

compose() {
  local env_args=()
  [[ -f "$ENV_FILE" ]] && env_args=("--env-file" "$ENV_FILE")
  docker compose "${env_args[@]}" "${compose_files[@]}" "$@"
}

require_color() {
  case "${1:-}" in
    blue|green) ;;
    *) echo "Usage: $0 <blue|green>" >&2; exit 2 ;;
  esac
}

other_color() {
  if [[ "$1" == "blue" ]]; then
    echo "green"
  else
    echo "blue"
  fi
}

write_scheduler_flag() {
  local color=$1 enabled=$2
  require_color "$color"
  case "$enabled" in true|false) ;; *) echo "enabled must be true or false" >&2; exit 2 ;; esac
  printf 'SCHEDULER_ENABLED=%s\n' "$enabled" > "$ROOT_DIR/env/$color.env"
}

render_active_config() {
  local color=$1 tmp
  require_color "$color"
  mkdir -p "$ROOT_DIR/traefik/dynamic"
  tmp=$(mktemp "$ROOT_DIR/traefik/dynamic/.active.yml.XXXXXX")
  sed \
    -e "s/__ACTIVE_COLOR__/$color/g" \
    -e "s/__APP_PORT__/$APP_PORT/g" \
    -e "s/__SERVICE_WEBHOOK_HOST__/$SERVICE_WEBHOOK_HOST/g" \
    "$DYNAMIC_TEMPLATE" > "$tmp"
  mv "$tmp" "$DYNAMIC_ACTIVE"
}

container_ready() {
  local color=$1 attempts=${2:-30}
  require_color "$color"
  for ((i = 1; i <= attempts; i++)); do
    if compose exec -T "service-webhook-$color" wget -qO- "http://127.0.0.1:$APP_PORT/readyz" >/dev/null 2>&1; then
      echo "service-webhook-$color ready"
      return 0
    fi
    sleep 2
  done
  echo "service-webhook-$color did not become ready after $attempts attempts" >&2
  return 1
}
