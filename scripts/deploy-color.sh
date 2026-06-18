#!/usr/bin/env bash
set -euo pipefail
# Build/pull and start the inactive candidate with scheduler disabled.
# Deploys ALL brands for the given color (atomic blue/green).

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

color=${1:-}
require_color "$color"

write_scheduler_flag "$color" false

# Deploy each brand service for this color
for brand in "${BRANDS[@]}"; do
  svc=$(brand_service "$brand" "$color")
  if [[ "$COMPOSE_MODE" == "build" ]]; then
    compose build "$svc"
  else
    compose pull "$svc"
  fi
  compose up -d --no-deps --force-recreate "$svc"
done

# Wait for all brand containers to become ready
all_brands_ready "$color" "${READY_ATTEMPTS:-30}"
