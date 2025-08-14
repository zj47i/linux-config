#!/usr/bin/env bash
set -euo pipefail

# ── 1) Git 저장소 루트 탐지 ──────────────────────────────────────────────
REPO_ROOT="${1:-}"
if [ -z "${REPO_ROOT}" ]; then
  if command -v git >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi
fi
if [ -z "${REPO_ROOT}" ]; then
  echo "사용법: ./link-i3.sh <git_repo_root>   (또는 git 저장소 안에서 실행)"
  exit 1
fi

# ── 2) 소스 설정 파일 경로 결정 (.config/i3/config → .i3/config 순) ────
SRC=""
if [ -f "${REPO_ROOT}/.config/i3/config" ]; then
  SRC="${REPO_ROOT}/.config/i3/config"
elif [ -f "${REPO_ROOT}/.i3/config" ]; then
  SRC="${REPO_ROOT}/.i3/config"
else
  echo "소스 설정 파일을 찾지 못했습니다: ${REPO_ROOT}/.config/i3/config 또는 ${REPO_ROOT}/.i3/config"
  exit 1
fi

# ── 3) 대상 경로 결정(XDG 사용 시 ~/.config/i3/config, 레거시 ~/.i3/config도 동시 링크) ─
CFG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET1="${CFG_HOME}/i3/config"  # 현대적 표준 경로
TARGET2="${HOME}/.i3/config"     # 레거시 경로(존재 시 참조하는 환경 대비)

backup_then_link () {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  # 이미 같은 링크면 건너뜀
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "이미 링크되어 있음: $dst -> $src"
    return 0
  fi

  # 기존 파일/디렉터리/다른 링크 백업
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv -v "$dst" "${dst}.bak.$(date +%s)"
  fi

  ln -s "$src" "$dst"
  echo "링크 생성: $dst -> $src"
}

backup_then_link "$SRC" "$TARGET1"
backup_then_link "$SRC" "$TARGET2" || true   # 필요 없으면 실패해도 무시

echo "완료. i3를 재적용하려면:  i3-msg reload  (필요 시 relaunch/login)"

