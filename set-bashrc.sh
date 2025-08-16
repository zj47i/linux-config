#!/usr/bin/env bash
set -euo pipefail

# Append common aliases to the current user's ~/.bashrc if missing.
# - Idempotent: skips if alias name already exists.

BASHRC_FILE="${HOME}/.bashrc"

ensure_alias() {
	local name="$1" def_line="$2"
	touch "$BASHRC_FILE"
	if grep -qxF "$def_line" "$BASHRC_FILE" 2>/dev/null; then
		echo "이미 동일 정의 존재: alias ${name}"
		return 0
	fi
	if grep -Ev '^[[:space:]]*#' "$BASHRC_FILE" | grep -Eq "^[[:space:]]*alias[[:space:]]+${name}="; then
		# 같은 이름이 있지만 내용이 다르면, 새 정의를 추가해 덮어씌우기(나중 정의가 우선)
		if ! grep -qxF '# --- linux-config: aliases ---' "$BASHRC_FILE" 2>/dev/null; then
			{
				echo ""
				echo "# --- linux-config: aliases ---"
			} >> "$BASHRC_FILE"
		fi
		echo "$def_line" >> "$BASHRC_FILE"
		echo "업데이트됨: $def_line"
	else
		if ! grep -qxF '# --- linux-config: aliases ---' "$BASHRC_FILE" 2>/dev/null; then
			{
				echo ""
				echo "# --- linux-config: aliases ---"
			} >> "$BASHRC_FILE"
		fi
		echo "$def_line" >> "$BASHRC_FILE"
		echo "추가됨: $def_line"
	fi
}

ensure_alias vi "alias vi=vim"
ensure_alias ll "alias ll='ls -al --color=auto'"

# --- prompt patch -------------------------------------------------------------
ensure_prompt_patch() {
  if grep -qF '# --- linux-config: prompt-patch ---' "$BASHRC_FILE" 2>/dev/null; then
    echo "이미 prompt patch 적용됨"
    return
  fi

  {
    echo ""
    echo "# --- linux-config: prompt-patch ---"
    cat <<'EOF'
# 대화형 셸에서만 적용
if [[ $- == *i* ]]; then
  # git-prompt 로드 (배포판별 경로 폴백)
  if [ -r /usr/share/git/completion/git-prompt.sh ]; then
    source /usr/share/git/completion/git-prompt.sh
  elif [ -r /etc/bash_completion.d/git-prompt ]; then
    source /etc/bash_completion.d/git-prompt
  elif [ -r /usr/share/git-core/contrib/completion/git-prompt.sh ]; then
    source /usr/share/git-core/contrib/completion/git-prompt.sh
  fi

  # 상태/업스트림 기호 비활성화 → 브랜치명만
  unset GIT_PS1_SHOWDIRTYSTATE GIT_PS1_SHOWSTASHSTATE GIT_PS1_SHOWUPSTREAM

  # 원래 PS1을 보존하고, \W/\w(또는 (\W)/(\w))을 "경로 공백 브랜치"로 치환
  if [ -z "${__PS1_PATCHED+x}" ]; then
    __PS1_PATCHED=1
    __PS1_ORIG="$PS1"

    # 브랜치만 색상(밝은 노랑/주황). 프롬프트 길이 계산 보호를 위해 \[ \] 사용.
    __REPL='\w$(__git_ps1 " \[\e[33;1m\]%s\[\e[0m\]")'

    if [[ "$__PS1_ORIG" == *'(\\W)'* ]]; then          # "( \W )" 패턴을 괄호 없이 치환
      PS1="${__PS1_ORIG//\(\\W\)/$__REPL}"
    elif [[ "$__PS1_ORIG" == *'(\\w)'* ]]; then         # "( \w )" 패턴을 괄호 없이 치환
      PS1="${__PS1_ORIG//\(\\w\)/$__REPL}"
    elif [[ "$__PS1_ORIG" == *'\W'* ]]; then            # \W 치환
      PS1="${__PS1_ORIG//\\W/$__REPL}"
    elif [[ "$__PS1_ORIG" == *'\w'* ]]; then            # \w 치환
      PS1="${__PS1_ORIG//\\w/$__REPL}"
    elif [[ "$__PS1_ORIG" == *'\\$ '* ]]; then          # 끝에 주입
      PS1="${__PS1_ORIG/\\$ /$__REPL\\$ }"
    else                                                # 아무 토큰도 없으면 그냥 덧붙임
      PS1="$__PS1_ORIG $__REPL "
    fi
  fi
fi
EOF
    echo "# --- /linux-config: prompt-patch ---"
  } >> "$BASHRC_FILE"

  echo "프롬프트 패치 추가됨"
}
# ----------------------------------------------------------------------------- 

ensure_prompt_patch


:

echo "완료. 새로운 셸에서 적용되며, 즉시 반영하려면: source \"$BASHRC_FILE\""

