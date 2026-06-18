#!/usr/bin/env bash
set -euo pipefail
# Verify Traefik routes the public host to a healthy active backend.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

url=${1:-"http://127.0.0.1:${TRAEFIK_HTTP_PORT:-80}/readyz"}
curl -fsS -H "Host: $SERVICE_WEBHOOK_HOST" "$url" >/dev/null
echo "Traefik readiness check passed for Host: $SERVICE_WEBHOOK_HOST at $url"
