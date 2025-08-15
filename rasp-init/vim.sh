#!/usr/bin/env bash
set -euo pipefail

# Root-only variant for fresh image initialization (no sudo prompts)

if ! command -v pacman >/dev/null 2>&1; then
  echo "이 스크립트는 Manjaro/Arch에서만 동작합니다." >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "이 스크립트는 root 권한으로만 실행됩니다. 예) sudo bash vim.sh 또는 root SSH 로그인" >&2
  exit 1
fi

# 패키지 업데이트 및 Vim 설치
pacman -Syu --noconfirm
pacman -S --noconfirm vim

# 설치 확인
if command -v vim >/dev/null 2>&1; then
  vim --version | head -n 1 || true
fi

echo "✅ Vim 설치 완료 (root 전용 스크립트)"
