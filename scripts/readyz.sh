#!/usr/bin/env bash
set -euo pipefail
# Check readiness inside the target service container.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

color=${1:-}
require_color "$color"
container_ready "$color" "${READY_ATTEMPTS:-1}"
