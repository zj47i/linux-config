#!/usr/bin/env bash
set -euo pipefail

# Root-only variant for fresh image initialization (no sudo prompts)

if ! command -v pacman >/dev/null 2>&1; then
  echo "이 스크립트는 Manjaro/Arch에서만 동작합니다." >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "이 스크립트는 root 권한으로만 실행됩니다. 예) sudo bash docker-root.sh 또는 root SSH 로그인" >&2
  exit 1
fi

# 패키지 업데이트 및 Docker 설치 (iptables-nft 우선 설치)
pacman -Syu --noconfirm
pacman -S iptables-nft
pacman -S --noconfirm nftables docker

# Docker 서비스 활성화
systemctl enable --now docker

# iptables 백엔드를 nft로 보장 (Arch/Manjaro에서는 iptables-nft 패키지로 대체됨)
if command -v iptables >/dev/null 2>&1; then
  iptables -V || true
fi

# docker 그룹에 일반 사용자 추가 (선택적)
# TARGET_USER 환경변수 우선, 없으면 SUDO_USER, 없으면 건너뜀
TARGET_USER="${TARGET_USER:-${SUDO_USER:-}}"
if [[ -n "${TARGET_USER}" && "${TARGET_USER}" != "root" ]]; then
  if ! id -nG "${TARGET_USER}" | grep -qw docker; then
    usermod -aG docker "${TARGET_USER}"
    echo "ℹ️  ${TARGET_USER} 사용자를 docker 그룹에 추가했습니다. 로그아웃/로그인 후 적용됩니다."
  fi
else
  echo "ℹ️  TARGET_USER 미지정 또는 root 입니다. docker 그룹 추가를 건너뜁니다. (필요 시: TARGET_USER=username 설정)"
fi

# 로그 로테이션 설정 (없을 때만 생성)
DAEMON_JSON=/etc/docker/daemon.json
if [[ ! -f "$DAEMON_JSON" ]]; then
  mkdir -p /etc/docker
  tee "$DAEMON_JSON" >/dev/null <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
JSON
  systemctl restart docker
fi

# 설치 확인
docker --version
# 가벼운 데몬 접근성 확인 (이미지 풀/실행 불필요)
docker info >/dev/null 2>&1 && echo "ℹ️  Docker daemon reachable" || echo "⚠️  Docker daemon not reachable yet"

echo "✅ Docker 설치 완료 (root 전용 스크립트)"
