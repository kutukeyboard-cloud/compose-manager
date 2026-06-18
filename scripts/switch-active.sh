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
compose up -d traefik

echo "Active color is now $new_color (brands: ${BRANDS[*]})"
