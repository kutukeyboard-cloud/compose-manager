#!/usr/bin/env bash
set -euo pipefail
# Stop the non-active color after verification.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

color=${1:-}
require_color "$color"
write_scheduler_flag "$color" false
compose stop "service-webhook-$color"
echo "Stopped service-webhook-$color"
