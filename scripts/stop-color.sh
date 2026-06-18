#!/usr/bin/env bash
set -euo pipefail
# Stop the non-active color after verification.
# Stops ALL brand containers for the given color.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

color=${1:-}
require_color "$color"
write_scheduler_flag "$color" false

for brand in "${BRANDS[@]}"; do
  svc=$(brand_service "$brand" "$color")
  compose stop "$svc"
  echo "Stopped $svc"
done
