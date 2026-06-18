#!/usr/bin/env bash
set -euo pipefail
# CI-friendly healthcheck for either a color container or the active Traefik route.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

target=${1:-active}
case "$target" in
  blue|green)
    all_brands_ready "$target" "${READY_ATTEMPTS:-1}"
    ;;
  active)
    "$ROOT_DIR/scripts/verify-active.sh"
    ;;
  *)
    echo "Usage: $0 [active|blue|green]" >&2
    exit 2
    ;;
esac
