#!/usr/bin/env bash
set -euo pipefail
# Roll traffic and scheduler ownership back to the supplied color.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

color=${1:-}
require_color "$color"
"$ROOT_DIR/scripts/switch-active.sh" "$color"
