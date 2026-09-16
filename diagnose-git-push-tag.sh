#!/usr/bin/env bash
# ============================================================================
# diagnose-git-push-tag.sh
# Diagnostic script to verify the Git push producer tag setup.
#
# Usage:  bash diagnose-git-push-tag.sh
# ============================================================================

set -euo pipefail

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { printf "  ${GREEN}✔${RESET} %-22s %s\n" "$1" "$2"; }
fail() { printf "  ${RED}✖${RESET} %-22s %s\n" "$1" "$2"; }
na()   { printf "  ${YELLOW}–${RESET} %-22s %s\n" "$1" "$2"; }

# ── Load config from .env ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
fi

# Defaults (used if .env is missing or incomplete)
WRAPPER_PATH="${WRAPPER_PATH:-$HOME/.local/bin/git}"
SOUNDS_DIR="${SOUNDS_DIR:-$HOME/.git-sounds}"
AUDIO_FILE="${AUDIO_FILE:-$SOUNDS_DIR/push.mp3}"
CURSOR_SETTINGS="${CURSOR_SETTINGS:-$HOME/Library/Application Support/Cursor/User/settings.json}"
ANTIGRAVITY_SETTINGS="${ANTIGRAVITY_SETTINGS:-$HOME/Library/Application Support/Antigravity IDE/User/settings.json}"

printf "\n${BOLD}Git Push Producer Tag – Diagnostic Report${RESET}\n"
printf "──────────────────────────────────────────\n\n"

# ── Terminal Git ─────────────────────────────────────────────────────────────
printf "${BOLD}Executables${RESET}\n"

# Export PATH with wrapper dir so `which` finds it
export PATH="$HOME/.local/bin:$PATH"

TERMINAL_GIT="$(which git 2>/dev/null || echo 'NOT FOUND')"
if [ "$TERMINAL_GIT" = "$WRAPPER_PATH" ]; then
    pass "Terminal Git:" "$TERMINAL_GIT (wrapper ✓)"
else
    fail "Terminal Git:" "$TERMINAL_GIT (expected $WRAPPER_PATH)"
fi

# ── Wrapper ──────────────────────────────────────────────────────────────────
if [ -f "$WRAPPER_PATH" ]; then
    if grep -q "git-push-producer-tag" "$WRAPPER_PATH" 2>/dev/null; then
        pass "Wrapper:" "$WRAPPER_PATH (valid ✓)"
    else
        fail "Wrapper:" "$WRAPPER_PATH (exists but not ours!)"
    fi
else
    fail "Wrapper:" "$WRAPPER_PATH (not found)"
fi

# ── Real Git (from wrapper) ──────────────────────────────────────────────────
if [ -f "$WRAPPER_PATH" ]; then
    REAL_GIT="$(grep '^REAL_GIT=' "$WRAPPER_PATH" 2>/dev/null | head -1 | cut -d'"' -f2)"
    if [ -x "$REAL_GIT" ]; then
        VERSION="$("$REAL_GIT" --version 2>/dev/null || echo 'unknown')"
        pass "Real Git:" "$REAL_GIT ($VERSION)"
    else
        fail "Real Git:" "$REAL_GIT (not executable!)"
    fi
else
    na "Real Git:" "(wrapper not found)"
fi

# ── Cursor Git ───────────────────────────────────────────────────────────────
if [ -f "$CURSOR_SETTINGS" ]; then
    CURSOR_GIT="$(python3 -c "
import json, re
with open('$CURSOR_SETTINGS') as f:
    content = f.read()
cleaned = re.sub(r',\s*([}\]])', r'\1', content)
d = json.loads(cleaned)
print(d.get('git.path', 'NOT SET (auto-detect from PATH)'))
" 2>/dev/null || echo 'PARSE ERROR')"

    if [ "$CURSOR_GIT" = "$WRAPPER_PATH" ]; then
        pass "Cursor Git:" "$CURSOR_GIT (wrapper ✓)"
    elif [ "$CURSOR_GIT" = "NOT SET (auto-detect from PATH)" ]; then
        na "Cursor Git:" "$CURSOR_GIT"
    else
        fail "Cursor Git:" "$CURSOR_GIT (unexpected)"
    fi
else
    na "Cursor Git:" "Settings file not found"
fi

# ── Antigravity Git ──────────────────────────────────────────────────────────
if [ -f "$ANTIGRAVITY_SETTINGS" ]; then
    AGY_GIT="$(python3 -c "
import json, re
with open('$ANTIGRAVITY_SETTINGS') as f:
    content = f.read()
cleaned = re.sub(r',\s*([}\]])', r'\1', content)
d = json.loads(cleaned)
print(d.get('git.path', 'NOT SET (auto-detect from PATH)'))
" 2>/dev/null || echo 'PARSE ERROR')"

    if [ "$AGY_GIT" = "$WRAPPER_PATH" ]; then
        pass "Antigravity Git:" "$AGY_GIT (wrapper ✓)"
    elif [ "$AGY_GIT" = "NOT SET (auto-detect from PATH)" ]; then
        na "Antigravity Git:" "$AGY_GIT"
    else
        fail "Antigravity Git:" "$AGY_GIT (unexpected)"
    fi
else
    na "Antigravity Git:" "Settings file not found"
fi

# ── Audio File ───────────────────────────────────────────────────────────────
printf "\n${BOLD}Audio${RESET}\n"

if [ -f "$AUDIO_FILE" ]; then
    SIZE="$(du -h "$AUDIO_FILE" | cut -f1 | xargs)"
    pass "Audio file:" "$AUDIO_FILE ($SIZE)"
else
    fail "Audio file:" "$AUDIO_FILE (not found)"
fi

if [ -d "$SOUNDS_DIR" ]; then
    pass "Sounds dir:" "$SOUNDS_DIR"
else
    fail "Sounds dir:" "$SOUNDS_DIR (not found)"
fi

# ── Forwarding Test ──────────────────────────────────────────────────────────
printf "\n${BOLD}Forwarding Test${RESET}\n"

if [ -f "$WRAPPER_PATH" ]; then
    WRAPPER_VERSION="$("$WRAPPER_PATH" --version 2>/dev/null || echo 'FAILED')"
    DIRECT_VERSION="$("$REAL_GIT" --version 2>/dev/null || echo 'FAILED')"
    if [ "$WRAPPER_VERSION" = "$DIRECT_VERSION" ]; then
        pass "Version match:" "$WRAPPER_VERSION ✓"
    else
        fail "Version mismatch:" "Wrapper=$WRAPPER_VERSION, Real=$DIRECT_VERSION"
    fi
else
    na "Forwarding:" "Wrapper not found – cannot test"
fi

# ── PATH Check ───────────────────────────────────────────────────────────────
printf "\n${BOLD}PATH${RESET}\n"

if echo "$PATH" | tr ':' '\n' | head -5 | grep -q "$HOME/.local/bin"; then
    pass "~/.local/bin:" "In PATH (near top) ✓"
else
    fail "~/.local/bin:" "NOT in PATH or not near top"
fi

# ── .zshrc Check ─────────────────────────────────────────────────────────────
if [ -f "$HOME/.zshrc" ]; then
    if grep -qF "git-push-producer-tag" "$HOME/.zshrc" 2>/dev/null; then
        pass ".zshrc:" "PATH entry present ✓"
    else
        fail ".zshrc:" "PATH entry not found"
    fi
else
    na ".zshrc:" "File not found"
fi

# ── Quick Test ───────────────────────────────────────────────────────────────
printf "\n${BOLD}Quick Audio Test${RESET}\n"
if [ -f "$AUDIO_FILE" ]; then
    printf "  Run:  ${CYAN}afplay %s${RESET}\n" "$AUDIO_FILE"
else
    printf "  Place your MP3 at:  ${CYAN}%s${RESET}\n" "$AUDIO_FILE"
fi

echo ""
