#!/usr/bin/env bash
set -euo pipefail
# Promote a ready API color by atomically switching Traefik file-provider
# config for all brands.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

new_color=${1:-}
require_color "$new_color"

# Recreate all new-color brand containers before promotion.
for brand in "${BRANDS[@]}"; do
  compose up -d --no-deps --force-recreate "$(brand_service "$brand" "$new_color")"
done

# Wait for all new-color containers to be ready
all_brands_ready "$new_color" "${READY_ATTEMPTS:-30}"

# Atomically switch Traefik routing to new color
render_active_config "$new_color"
for brand in "${BRANDS[@]}"; do
  active_color=$(active_color_for_brand "$brand")
  if [[ "$active_color" != "$new_color" ]]; then
    echo "Failed to update active color for $brand in $DYNAMIC_ACTIVE (expected $new_color, got $active_color)" >&2
    exit 1
  fi
done

echo "Active color is now $new_color (brands: ${BRANDS[*]})"
echo "Active config: $DYNAMIC_ACTIVE"
