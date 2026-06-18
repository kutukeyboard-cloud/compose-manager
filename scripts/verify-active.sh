#!/usr/bin/env bash
set -euo pipefail
# Verify Traefik routes each brand's public port to a healthy active backend.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

verixa_url=${VERIXA_VERIFY_URL:-"http://127.0.0.1:${VERIXA_TRAEFIK_PORT:-8900}/readyz"}
lgpay_url=${LGPAY_VERIFY_URL:-"http://127.0.0.1:${LGPAY_TRAEFIK_PORT:-8902}/readyz"}

curl -fsS "$verixa_url" >/dev/null
echo "Traefik readiness check passed for Verixa at $verixa_url"

curl -fsS "$lgpay_url" >/dev/null
echo "Traefik readiness check passed for Lgpay at $lgpay_url"
