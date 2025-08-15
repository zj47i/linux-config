#!/usr/bin/env bash
set -euo pipefail

# Root-only script to switch wait-online from systemd-networkd to NetworkManager
# - Always tries to stop/disable/mask networkd wait-online and networkd
# - Then enables NetworkManager and NetworkManager-wait-online
# Optional: pass --reboot to reboot after changes

if [[ "${EUID}" -ne 0 ]]; then
  echo "이 스크립트는 root 권한으로만 실행됩니다." >&2
  exit 1
fi

REBOOT=0
if [[ "${1:-}" == "--reboot" ]]; then
  REBOOT=1
fi

# Always try to disable/mask systemd-networkd wait-online and disable networkd
echo "🔧 Disabling systemd-networkd-wait-online.service (if present)"
systemctl disable --now systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
echo "🔧 Disabling systemd-networkd.service (if present)"
systemctl disable --now systemd-networkd.service 2>/dev/null || true

# Enable NetworkManager and its wait-online (let systemd handle presence)
echo "🔧 Enabling NetworkManager.service"
systemctl enable --now NetworkManager.service
echo "🔧 Enabling NetworkManager-wait-online.service"
systemctl enable --now NetworkManager-wait-online.service

# Show status (non-fatal)
systemctl is-enabled systemd-networkd-wait-online.service 2>/dev/null || true
systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null || true


echo "✅ wait-online 서비스 스위치 완료"

if [[ $REBOOT -eq 1 ]]; then
  echo "🔁 Rebooting..."
  systemctl reboot
fi
