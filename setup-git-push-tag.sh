#!/usr/bin/env bash
# ============================================================================
# setup-git-push-tag.sh
# Sets up a transparent Git wrapper that plays a producer tag audio file
# after every successful `git push`.
#
# Works for: Terminal, Cursor, and Antigravity IDE.
#
# Usage:  bash setup-git-push-tag.sh
# Idempotent – safe to run multiple times.
# ============================================================================

set -euo pipefail

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}ℹ${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}✔${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${RESET}  %s\n" "$*"; }
err()   { printf "${RED}✖${RESET}  %s\n" "$*" >&2; }
header(){ printf "\n${BOLD}── %s ──${RESET}\n\n" "$*"; }

# ── Load config from .env ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
fi

# Defaults (used if .env is missing or incomplete)
WRAPPER_DIR="${WRAPPER_DIR:-$HOME/.local/bin}"
WRAPPER_PATH="${WRAPPER_PATH:-$WRAPPER_DIR/git}"
SOUNDS_DIR="${SOUNDS_DIR:-$HOME/.git-sounds}"
AUDIO_FILE="${AUDIO_FILE:-$SOUNDS_DIR/push.mp3}"
ZSHRC="${ZSHRC:-$HOME/.zshrc}"
CURSOR_SETTINGS="${CURSOR_SETTINGS:-$HOME/Library/Application Support/Cursor/User/settings.json}"
ANTIGRAVITY_SETTINGS="${ANTIGRAVITY_SETTINGS:-$HOME/Library/Application Support/Antigravity IDE/User/settings.json}"

# ── Step 1: Detect real Git ─────────────────────────────────────────────────
header "Step 1: Detecting real Git executable"

# Try Homebrew first, then system
if [ -x "/opt/homebrew/bin/git" ]; then
    REAL_GIT="/opt/homebrew/bin/git"
elif [ -x "/usr/local/bin/git" ]; then
    REAL_GIT="/usr/local/bin/git"
elif [ -x "/usr/bin/git" ]; then
    REAL_GIT="/usr/bin/git"
else
    err "No Git installation found. Please install Git first."
    exit 1
fi

# Make sure we're not pointing at ourselves
RESOLVED_GIT="$(realpath "$REAL_GIT" 2>/dev/null || readlink -f "$REAL_GIT" 2>/dev/null || echo "$REAL_GIT")"
info "Real Git executable: $REAL_GIT"
info "Resolved path:       $RESOLVED_GIT"
info "Version:             $($REAL_GIT --version)"

# ── Step 2: Create directories ──────────────────────────────────────────────
header "Step 2: Creating directories"

mkdir -p "$WRAPPER_DIR"
ok "Created $WRAPPER_DIR"

mkdir -p "$SOUNDS_DIR"
ok "Created $SOUNDS_DIR"

# ── Step 3: Write the Git wrapper ───────────────────────────────────────────
header "Step 3: Writing Git wrapper"

# Check if a wrapper already exists and is ours
if [ -f "$WRAPPER_PATH" ]; then
    if grep -q "git-push-producer-tag" "$WRAPPER_PATH" 2>/dev/null; then
        info "Wrapper already exists (ours). Overwriting with latest version."
    else
        warn "A file already exists at $WRAPPER_PATH that was NOT created by this script."
        warn "Backing up to ${WRAPPER_PATH}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$WRAPPER_PATH" "${WRAPPER_PATH}.backup.$(date +%Y%m%d%H%M%S)"
    fi
fi

cat > "$WRAPPER_PATH" << 'WRAPPER_EOF'
#!/bin/bash
# git-push-producer-tag: Transparent Git wrapper
# Plays ~/.git-sounds/push.mp3 after a successful git push.
# All arguments, stdout, stderr, and exit codes are preserved exactly.
# ──────────────────────────────────────────────────────────────────
REAL_GIT="__REAL_GIT_PLACEHOLDER__"

# Forward everything to the real Git
"$REAL_GIT" "$@"
__git_exit_status=$?

# Only act on success
if [ $__git_exit_status -eq 0 ]; then
    # Determine if the subcommand is "push" by scanning for the first
    # non-flag argument. This avoids matching flags like --push-option.
    __is_push=0
    for __arg in "$@"; do
        case "$__arg" in
            -*)  continue ;;          # skip flags (e.g. -v, --verbose, -c key=val)
            push) __is_push=1; break ;;
            *)    break ;;            # first positional arg is not "push"
        esac
    done

    if [ $__is_push -eq 1 ] && [ -f "$HOME/.git-sounds/push.mp3" ]; then
        ( afplay "$HOME/.git-sounds/push.mp3" >/dev/null 2>&1 & )
    fi
fi

exit $__git_exit_status
WRAPPER_EOF

# Substitute the real git path into the wrapper
sed -i '' "s|__REAL_GIT_PLACEHOLDER__|${REAL_GIT}|g" "$WRAPPER_PATH"

chmod +x "$WRAPPER_PATH"
ok "Wrapper written to $WRAPPER_PATH"
info "Real Git hardcoded as: $REAL_GIT"

# ── Step 4: Ensure ~/.local/bin is in PATH via .zshrc ────────────────────────
header "Step 4: Configuring shell PATH"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
MARKER="# git-push-producer-tag: add wrapper to PATH"

if [ -f "$ZSHRC" ]; then
    if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
        ok "PATH entry already present in $ZSHRC – skipping."
    else
        # Backup .zshrc
        cp "$ZSHRC" "${ZSHRC}.backup.git-push-tag.$(date +%Y%m%d%H%M%S)"
        ok "Backed up $ZSHRC"
        printf '\n%s\n%s\n' "$MARKER" "$PATH_LINE" >> "$ZSHRC"
        ok "Added ~/.local/bin to PATH in $ZSHRC"
    fi
else
    printf '%s\n%s\n' "$MARKER" "$PATH_LINE" > "$ZSHRC"
    ok "Created $ZSHRC with PATH entry"
fi

# ── Step 5: Configure Cursor's git.path ──────────────────────────────────────
header "Step 5: Configuring Cursor"

configure_editor_git_path() {
    local settings_file="$1"
    local editor_name="$2"

    if [ ! -f "$settings_file" ]; then
        warn "$editor_name settings not found at $settings_file – skipping."
        return
    fi

    # Check if git.path is already set to our wrapper
    if python3 -c "
import json, sys
with open('$settings_file') as f:
    # Handle trailing commas by trying to parse, fallback gracefully
    content = f.read()
d = json.loads(content)
gp = d.get('git.path', '')
if gp == '$WRAPPER_PATH':
    sys.exit(0)
else:
    sys.exit(1)
" 2>/dev/null; then
        ok "$editor_name already configured – skipping."
        return
    fi

    # Backup
    cp "$settings_file" "${settings_file}.backup.git-push-tag.$(date +%Y%m%d%H%M%S)"
    ok "Backed up $editor_name settings"

    # Use python3 to safely modify JSON (handles trailing commas via a lenient approach)
    python3 << PYEOF
import json, re, sys

settings_file = "$settings_file"
wrapper_path = "$WRAPPER_PATH"

with open(settings_file, 'r') as f:
    content = f.read()

# Remove trailing commas before } or ] (common in VS Code JSON)
cleaned = re.sub(r',\s*([}\]])', r'\1', content)

try:
    d = json.loads(cleaned)
except json.JSONDecodeError:
    print(f"Warning: Could not parse {settings_file} – skipping.", file=sys.stderr)
    sys.exit(1)

d['git.path'] = wrapper_path

with open(settings_file, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

PYEOF

    if [ $? -eq 0 ]; then
        ok "$editor_name git.path set to $WRAPPER_PATH"
    else
        warn "Could not configure $editor_name automatically. Please add manually:"
        warn '  "git.path": "'"$WRAPPER_PATH"'"'
    fi
}

configure_editor_git_path "$CURSOR_SETTINGS" "Cursor"

# ── Step 6: Configure Antigravity IDE's git.path ─────────────────────────────
header "Step 6: Configuring Antigravity IDE"

configure_editor_git_path "$ANTIGRAVITY_SETTINGS" "Antigravity IDE"

# ── Step 7: Verification ────────────────────────────────────────────────────
header "Step 7: Verification"

# Source the updated PATH for this session
export PATH="$HOME/.local/bin:$PATH"

# Check wrapper is on PATH
WHICH_GIT="$(which git 2>/dev/null || echo 'NOT FOUND')"
if [ "$WHICH_GIT" = "$WRAPPER_PATH" ]; then
    ok "which git → $WRAPPER_PATH ✓"
else
    warn "which git → $WHICH_GIT (expected $WRAPPER_PATH)"
    warn "Open a new terminal or run: source ~/.zshrc"
fi

# Check wrapper works
WRAPPER_VERSION="$("$WRAPPER_PATH" --version 2>/dev/null || echo 'FAILED')"
REAL_VERSION="$("$REAL_GIT" --version 2>/dev/null || echo 'FAILED')"
if [ "$WRAPPER_VERSION" = "$REAL_VERSION" ]; then
    ok "Wrapper forwards git --version correctly: $WRAPPER_VERSION ✓"
else
    err "Version mismatch! Wrapper: $WRAPPER_VERSION, Real: $REAL_VERSION"
fi

# Check audio file
if [ -f "$AUDIO_FILE" ]; then
    ok "Audio file found: $AUDIO_FILE ✓"
else
    warn "Audio file NOT found: $AUDIO_FILE"
    warn "Place your producer tag MP3 at: $AUDIO_FILE"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
header "Setup Complete"

printf "${BOLD}%-20s${RESET} %s\n" "Wrapper:" "$WRAPPER_PATH"
printf "${BOLD}%-20s${RESET} %s\n" "Real Git:" "$REAL_GIT"
printf "${BOLD}%-20s${RESET} %s\n" "Audio file:" "$AUDIO_FILE"
printf "${BOLD}%-20s${RESET} %s\n" "Sounds dir:" "$SOUNDS_DIR"

echo ""
info "Next steps:"
echo "  1. Place your producer tag MP3 at:"
printf "     ${CYAN}%s${RESET}\n" "$AUDIO_FILE"
echo ""
echo "  2. Test the audio:"
printf "     ${CYAN}afplay %s${RESET}\n" "$AUDIO_FILE"
echo ""
echo "  3. Open a new Terminal tab (or run: source ~/.zshrc)"
echo ""
echo "  4. Restart Cursor and Antigravity IDE to pick up git.path"
echo ""
echo "  5. Test with a git push:"
printf "     ${CYAN}git push${RESET}\n"
echo ""
info "Run the diagnostic script to verify everything:"
printf "     ${CYAN}bash %s/diagnose-git-push-tag.sh${RESET}\n" "$(cd "$(dirname "$0")" && pwd)"
echo ""
