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

# ── Brand registry ──────────────────────────────────────────────────────────
# All managed brands. Phase 1 = atomic color switch (all brands switch together).
BRANDS=(verixa lgpay sandbox)

# Per-brand port mapping
VERIXA_PORT=${VERIXA_PORT:-8900}
LGPAY_PORT=${LGPAY_PORT:-8902}
SANDBOX_PORT=${SANDBOX_PORT:-8904}

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

# Return the internal port for a brand
brand_port() {
  local brand=$1
  case "$brand" in
    verixa) echo "$VERIXA_PORT" ;;
    lgpay)  echo "$LGPAY_PORT" ;;
    sandbox) echo "$SANDBOX_PORT" ;;
    *)      echo "Unknown brand: $brand" >&2; exit 2 ;;
  esac
}

# Return the compose service name for a brand+color
brand_service() {
  local brand=$1 color=$2
  echo "api-${brand}-${color}"
}

# Return all compose service names for a given color (all brands)
color_services() {
  local color=$1
  for brand in "${BRANDS[@]}"; do
    echo "api-${brand}-${color}"
  done
}

render_active_config() {
  local color=$1 tmp
  require_color "$color"
  mkdir -p "$ROOT_DIR/traefik/dynamic"
  tmp=$(mktemp "$ROOT_DIR/traefik/dynamic/.active.yml.XXXXXX")
  sed \
    -e "s/__ACTIVE_COLOR__/$color/g" \
    -e "s/__VERIXA_PORT__/$VERIXA_PORT/g" \
    -e "s/__LGPAY_PORT__/$LGPAY_PORT/g" \
    -e "s/__SANDBOX_PORT__/$SANDBOX_PORT/g" \
    "$DYNAMIC_TEMPLATE" > "$tmp"
  mv "$tmp" "$DYNAMIC_ACTIVE"
}

# Wait for a single brand+color container to pass /readyz
container_ready() {
  local brand=$1 color=$2 attempts=${3:-30}
  local svc port
  svc=$(brand_service "$brand" "$color")
  port=$(brand_port "$brand")
  for ((i = 1; i <= attempts; i++)); do
    if compose exec -T "$svc" wget -qO- "http://127.0.0.1:$port/readyz" >/dev/null 2>&1; then
      echo "$svc ready"
      return 0
    fi
    sleep 2
  done
  echo "$svc did not become ready after $attempts attempts" >&2
  return 1
}

# Wait for ALL brand containers of a given color to pass /readyz
all_brands_ready() {
  local color=$1 attempts=${2:-30}
  for brand in "${BRANDS[@]}"; do
    container_ready "$brand" "$color" "$attempts"
  done
}
