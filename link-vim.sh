#!/usr/bin/env bash
set -euo pipefail

# 단일 용도: 저장소의 vimrc 를 $HOME/.vim/vimrc 로 심볼릭 링크
# 사용법:
#   ./link-vim.sh            (git 저장소 안에서)
#   ./link-vim.sh /repo/path (명시적 루트)
# 환경변수:
#   FORCE=1  동일 링크여도 재생성

REPO_ROOT="${1:-}"
if [ -z "$REPO_ROOT" ]; then
  if command -v git >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi
fi
if [ -z "$REPO_ROOT" ]; then
  echo "사용법: ./link-vim.sh <git_repo_root> (또는 저장소 내부에서 실행)" >&2
  exit 1
fi

# 소스 탐색: 우선순위 .vim/vimrc → .config/vim/vimrc
if [ -f "$REPO_ROOT/.vim/vimrc" ]; then
  SRC="$REPO_ROOT/.vim/vimrc"
elif [ -f "$REPO_ROOT/.config/vim/vimrc" ]; then
  SRC="$REPO_ROOT/.config/vim/vimrc"
else
  echo "소스 vimrc 없음: $REPO_ROOT/.vim/vimrc 또는 .config/vim/vimrc" >&2
  exit 1
fi

TARGET="$HOME/.vim/vimrc"
mkdir -p "$(dirname "$TARGET")"

if [ "${FORCE:-0}" != 1 ] && [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET" 2>/dev/null || true)" = "$(readlink -f "$SRC")" ]; then
  echo "이미 링크되어 있음: $TARGET -> $SRC"
else
  if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    mv -v "$TARGET" "$TARGET.bak.$(date +%s)"
  fi
  ln -s "$SRC" "$TARGET"
  echo "링크 생성: $TARGET -> $SRC"
fi

# vimrc 내부에서 undodir=~/.vim/undodir 사용 → 디렉터리 보장
UNDO_DIR="$HOME/.vim/undodir"
if [ ! -d "$UNDO_DIR" ]; then
  mkdir -p "$UNDO_DIR"
  echo "생성: $UNDO_DIR"
fi

echo "완료. Vim에서 :source $TARGET 로 재적용 가능"
