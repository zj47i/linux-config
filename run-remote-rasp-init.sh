#!/usr/bin/env bash
set -euo pipefail

# Orchestrate: sync rasp-init to remote, run setup scripts (docker, vim, aliases), then switch wait-online services
# Usage:
#   ./run-remote-rasp-init.sh [HOST_ALIAS] [DEST_DIR] [--clean] [--reboot]
# Defaults:
#   HOST_ALIAS = rasp-private
#   DEST_DIR   = /tmp/rasp-init
# Examples:
#   ./run-remote-rasp-init.sh
#   ./run-remote-rasp-init.sh rasp-private
#   ./run-remote-rasp-init.sh rasp-private /tmp/rasp-init
#   ./run-remote-rasp-init.sh rasp-private /tmp/rasp-init --clean --reboot
# Scripts executed remotely (if present, in this order):
#   1) docker.sh
#   2) vim.sh
#   3) bashrc-aliases.sh
#   4) network-wait-online.sh [--reboot]

HOST="${1:-rasp-private}"
DEST="${2:-/tmp/rasp-init}"
CLEAN=0
REBOOT_FLAG=""
# Parse optional flags in any order from $3 and $4
for arg in "${3:-}" "${4:-}"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --reboot) REBOOT_FLAG="--reboot" ;;
    "" ) ;;
    *) echo "알 수 없는 옵션: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/rasp-init"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "소스 디렉토리를 찾을 수 없습니다: $SRC_DIR" >&2
  exit 1
fi

echo "➡️  Sync: $SRC_DIR -> $HOST:$DEST"

ensure_remote_dir() {
  ssh -o BatchMode=yes "$HOST" "mkdir -p \"$DEST\""
}

is_safe_clean() {
  case "$DEST" in
    "/"|"/tmp"|"/var/tmp"|"/home"|"/root"|"/usr"|"/opt") return 1;;
    */rasp-init|*/rasp-init/) return 0;;
    *) return 1;;
  esac
}

remote_clean_if_requested() {
  if [[ $CLEAN -eq 1 ]]; then
    if is_safe_clean; then
      ssh -o BatchMode=yes "$HOST" "set -e; mkdir -p \"$DEST\"; find \"$DEST\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
      echo "🧹 원격 정리 완료: $HOST:$DEST"
    else
      echo "⚠️  안전을 위해 '--clean' 을 무시합니다 (DEST: $DEST)."
    fi
  fi
}

ensure_remote_dir
remote_clean_if_requested
tar czf - -C "$SRC_DIR" . | ssh -o BatchMode=yes "$HOST" "tar xzf - -C \"$DEST\""
echo "✅ Sync 완료 (ssh/tar): $SRC_DIR -> $HOST:$DEST"

run_remote_if_exists() {
  local script_name="$1"; shift || true
  local extra_args=("$@")
  echo "➡️  Remote: $script_name on $HOST"
  ssh -t "$HOST" "bash -c 'if [ -f \"$DEST/${script_name}\" ]; then sudo bash \"$DEST/${script_name}\" ${extra_args[*]}; else echo \"ℹ️  $DEST/${script_name} 없음 (건너뜀)\"; fi'"
}

# Execute scripts on remote in order
run_remote_if_exists docker.sh
run_remote_if_exists vim.sh
run_remote_if_exists bashrc-aliases.sh
run_remote_if_exists network-wait-online.sh "$REBOOT_FLAG"

echo "✅ Completed: remote RASP init on $HOST"
