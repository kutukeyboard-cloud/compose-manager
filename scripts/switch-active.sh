#!/usr/bin/env bash
set -euo pipefail
# Promote a ready color: enable its scheduler, disable the old scheduler, then atomically switch Traefik file-provider config.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

new_color=${1:-}
require_color "$new_color"
old_color=$(other_color "$new_color")

write_scheduler_flag "$new_color" true
write_scheduler_flag "$old_color" false
compose up -d --no-deps --force-recreate "service-webhook-$new_color"
container_ready "$new_color" "${READY_ATTEMPTS:-30}"
render_active_config "$new_color"
compose up -d traefik
compose up -d --no-deps --force-recreate "service-webhook-$old_color" || true
echo "Active service-webhook color is now $new_color"
