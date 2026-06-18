#!/usr/bin/env bash
set -euo pipefail
# Promote a ready color: enable its scheduler, disable the old scheduler,
# then atomically switch Traefik file-provider config for all brands.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

new_color=${1:-}
require_color "$new_color"
old_color=$(other_color "$new_color")

# Update scheduler flags
write_scheduler_flag "$new_color" true
write_scheduler_flag "$old_color" false

# Recreate all new-color brand containers (picks up SCHEDULER_ENABLED=true)
for brand in "${BRANDS[@]}"; do
  compose up -d --no-deps --force-recreate "$(brand_service "$brand" "$new_color")"
done

# Wait for all new-color containers to be ready
all_brands_ready "$new_color" "${READY_ATTEMPTS:-30}"

# Atomically switch Traefik routing to new color
render_active_config "$new_color"
compose up -d traefik

# Best-effort recreate old-color containers with scheduler disabled
for brand in "${BRANDS[@]}"; do
  compose up -d --no-deps --force-recreate "$(brand_service "$brand" "$old_color")" || true
done

echo "Active color is now $new_color (brands: ${BRANDS[*]})"
