#!/usr/bin/env bash
set -euo pipefail

# Deploy (symlink) everything under this repository's .config/ into $HOME/.config/
# - Backs up existing targets (files or dirs) unless --force specified.
# - Recurses into directories when the target directory already exists (merging).
# - Skips items already correctly linked.
#
# Usage:
#   ./link-config.sh           # normal run (creates backups)
#   ./link-config.sh --force   # replace existing without backup
#   DRYRUN=1 ./link-config.sh  # show what would happen
#
# Env:
#   DRYRUN=1   Only print actions.
#
# Notes:
#   If a top-level entry (e.g. kitty) does not yet exist in ~/.config, we create a single symlink for that directory.
#   If it already exists as a directory (not the desired symlink), we merge: link individual files recursively inside.

FORCE=0
if [[ ${1:-} == --force || ${1:-} == -f ]]; then
  FORCE=1
fi

if ! command -v date >/dev/null 2>&1; then
  echo "date command required" >&2
  exit 1
fi

# Resolve repo root (directory containing this script)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
SRC_ROOT="$REPO_ROOT/.config"
TARGET_ROOT="$HOME/.config"

if [[ ! -d $SRC_ROOT ]]; then
  echo "No .config directory found in repo ($SRC_ROOT)" >&2
  exit 1
fi

mkdir -p "$TARGET_ROOT"

backup() {
  local path="$1"
  [[ $FORCE -eq 1 ]] && return 0
  if [[ -e $path || -L $path ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local bak="${path}.bak.${ts}"
    echo "Backup: $path -> $bak"
    [[ ${DRYRUN:-0} == 1 ]] || mv -- "$path" "$bak"
  fi
}

link_file() {
  local src="$1" dest="$2"
  if [[ -L $dest ]]; then
    # existing symlink
    local current
    current="$(readlink "$dest" || true)"
    if [[ "$current" == "$src" ]]; then
      echo "Skip (already linked): $dest"
      return 0
    fi
  fi
  if [[ -e $dest || -L $dest ]]; then
    backup "$dest"
    [[ ${DRYRUN:-0} == 1 && $FORCE -eq 1 ]] && echo "(force remove) $dest"
    [[ ${DRYRUN:-0} == 1 ]] || rm -rf -- "$dest"
  fi
  echo "Link: $dest -> $src"
  [[ ${DRYRUN:-0} == 1 ]] || ln -s -- "$src" "$dest"
}

merge_dir() {
  local src_dir="$1" dest_dir="$2"
  # Recurse entries
  shopt -s nullglob dotglob
  for entry in "$src_dir"/*; do
    local rel
    rel="${entry#$src_dir/}"
    local target="$dest_dir/$rel"
    if [[ -d $entry && ! -L $entry ]]; then
      mkdir -p "$target"
      merge_dir "$entry" "$target"
    else
      local parent
      parent="$(dirname "$target")"
      mkdir -p "$parent"
      link_file "$entry" "$target"
    fi
  done
}

process_entry() {
  local src="$1"
  local name
  name="$(basename "$src")"
  local dest="$TARGET_ROOT/$name"

  if [[ -L $dest ]]; then
    # If already correct symlink, skip
    local current
    current="$(readlink "$dest" || true)"
    if [[ "$current" == "$src" ]]; then
      echo "Skip (already linked): $dest"
      return 0
    fi
  fi

  if [[ -e $dest && ! -d $dest && ! -L $dest ]]; then
    # existing file (not dir) -> replace with symlink
    link_file "$src" "$dest"
    return 0
  fi

  if [[ -d $src ]]; then
    if [[ -e $dest && -d $dest && ! -L $dest ]]; then
      echo "Merge directory: $src -> $dest"
      merge_dir "$src" "$dest"
    else
      # dest missing or is broken symlink / file
      link_file "$src" "$dest"
    fi
  else
    # simple file under .config root (rare)
    link_file "$src" "$dest"
  fi
}

shopt -s nullglob
entries=("$SRC_ROOT"/*)
if [[ ${#entries[@]} -eq 0 ]]; then
  echo "No entries under $SRC_ROOT" >&2
  exit 0
fi

for e in "${entries[@]}"; do
  process_entry "$e"
done

echo "Done."
