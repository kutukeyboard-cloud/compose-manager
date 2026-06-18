#!/usr/bin/env bash
set -euo pipefail
# Show compose service state for operator/CI diagnostics.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

compose ps "$@"
