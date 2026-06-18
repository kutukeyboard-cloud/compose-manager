#!/usr/bin/env bash
set -euo pipefail
# Build/pull and start the inactive candidate with scheduler disabled.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

color=${1:-}
require_color "$color"

write_scheduler_flag "$color" false
if [[ "$COMPOSE_MODE" == "build" ]]; then
  compose build "service-webhook-$color"
else
  compose pull "service-webhook-$color"
fi
compose up -d --no-deps --force-recreate "service-webhook-$color"
container_ready "$color" "${READY_ATTEMPTS:-30}"
