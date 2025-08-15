#!/usr/bin/env bash
set -euo pipefail

# Root-only script to add common aliases to root and rasp users' .bashrc
# - Adds: alias vi=vim, alias ll='ls -al'
# - Idempotent: won't duplicate lines if already present

if [[ "${EUID}" -ne 0 ]]; then
  echo "이 스크립트는 root 권한으로만 실행됩니다. 예) sudo bash rasp-init/bashrc-aliases.sh" >&2
  exit 1
fi

ensure_aliases() {
  local bashrc_file="$1"
  # Ensure file exists
  touch "$bashrc_file"

  # Helper to append a line if not present (exact match)
  _add_line() {
    local line="$1"
    if ! grep -qxF "$line" "$bashrc_file" 2>/dev/null; then
      echo "$line" >> "$bashrc_file"
    fi
  }

  # Add aliases
  _add_line "# --- linux-config: common aliases ---"
  _add_line "alias vi=vim"
  _add_line "alias ll='ls -al'"
}

update_user() {
  local user="$1"
  if ! id "$user" >/dev/null 2>&1; then
    echo "⚠️  사용자 '$user' 를 찾을 수 없어 건너뜁니다."
    return 0
  fi

  local home
  if [[ "$user" == "root" ]]; then
    home="/root"
  else
    home="$(getent passwd "$user" | cut -d: -f6)"
  fi

  if [[ -z "$home" || ! -d "$home" ]]; then
    echo "⚠️  사용자 '$user' 의 홈디렉토리를 찾을 수 없어 건너뜁니다."
    return 0
  fi

  local bashrc="$home/.bashrc"
  ensure_aliases "$bashrc"
  chown "$user":"$user" "$bashrc" || true
  echo "✅ ${user} 의 .bashrc 업데이트: $bashrc"
}

update_user root
update_user rasp

echo "완료: root, rasp 사용자에 vi/vim, ll 별칭 적용"
