#!/usr/bin/env bash
set -euo pipefail
# Promote one brand API color while preserving the active colors of other brands.

# shellcheck source=scripts/lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

service=${1:-}
new_color=${2:-}
require_service_name "$service"
require_color "$new_color"

brand=$(service_brand "$service")

# Recreate and verify only the requested brand/color before routing traffic.
compose up -d --no-deps --force-recreate "$(brand_service "$brand" "$new_color")"
container_ready "$brand" "$new_color" "${READY_ATTEMPTS:-30}"

verixa_color=$(active_color_for_brand verixa)
lgpay_color=$(active_color_for_brand lgpay)
sandbox_color=$(active_color_for_brand sandbox)

case "$brand" in
  verixa) verixa_color=$new_color ;;
  lgpay) lgpay_color=$new_color ;;
  sandbox) sandbox_color=$new_color ;;
esac

render_active_config_for_colors "$verixa_color" "$lgpay_color" "$sandbox_color"
actual_color=$(active_color_for_brand "$brand")
if [[ "$actual_color" != "$new_color" ]]; then
  echo "Failed to update active color for $service in $DYNAMIC_ACTIVE (expected $new_color, got $actual_color)" >&2
  exit 1
fi

echo "Active color for $service is now $new_color"
echo "Active colors: verixa=$verixa_color lgpay=$lgpay_color sandbox=$sandbox_color"
echo "Active config: $DYNAMIC_ACTIVE"
