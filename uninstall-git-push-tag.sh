#!/usr/bin/env bash
# ============================================================================
# uninstall-git-push-tag.sh
# Removes the Git push producer tag wrapper and restores original config.
#
# Usage:  bash uninstall-git-push-tag.sh
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
WRAPPER_PATH="${WRAPPER_PATH:-$HOME/.local/bin/git}"
SOUNDS_DIR="${SOUNDS_DIR:-$HOME/.git-sounds}"
ZSHRC="${ZSHRC:-$HOME/.zshrc}"
MARKER="# git-push-producer-tag: add wrapper to PATH"
CURSOR_SETTINGS="${CURSOR_SETTINGS:-$HOME/Library/Application Support/Cursor/User/settings.json}"
ANTIGRAVITY_SETTINGS="${ANTIGRAVITY_SETTINGS:-$HOME/Library/Application Support/Antigravity IDE/User/settings.json}"

# ── Step 1: Remove the Git wrapper ──────────────────────────────────────────
header "Step 1: Removing Git wrapper"

if [ -f "$WRAPPER_PATH" ]; then
    if grep -q "git-push-producer-tag" "$WRAPPER_PATH" 2>/dev/null; then
        rm "$WRAPPER_PATH"
        ok "Removed wrapper: $WRAPPER_PATH"
    else
        warn "$WRAPPER_PATH exists but was NOT created by this setup. Leaving it alone."
    fi
else
    info "Wrapper not found at $WRAPPER_PATH – nothing to remove."
fi

# Clean up empty .local/bin directory
if [ -d "$HOME/.local/bin" ] && [ -z "$(ls -A "$HOME/.local/bin" 2>/dev/null)" ]; then
    rmdir "$HOME/.local/bin" 2>/dev/null && ok "Removed empty directory: ~/.local/bin"
fi

# ── Step 2: Remove PATH entry from .zshrc ────────────────────────────────────
header "Step 2: Cleaning .zshrc"

if [ -f "$ZSHRC" ]; then
    if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
        # Backup first
        cp "$ZSHRC" "${ZSHRC}.backup.uninstall.$(date +%Y%m%d%H%M%S)"
        ok "Backed up $ZSHRC"

        # Remove the marker line and the PATH line immediately after it
        # Use a temp file to avoid sed -i differences
        awk -v marker="$MARKER" '
        BEGIN { skip_next = 0 }
        {
            if (skip_next == 1) {
                skip_next = 0
                next
            }
            if (index($0, marker) > 0) {
                skip_next = 1
                next
            }
            print
        }
        ' "$ZSHRC" > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC"

        ok "Removed PATH entry from $ZSHRC"
    else
        info "No git-push-producer-tag PATH entry found in $ZSHRC."
    fi
else
    info ".zshrc not found – nothing to clean."
fi

# ── Step 3: Remove git.path from editor settings ────────────────────────────
header "Step 3: Cleaning editor settings"

remove_editor_git_path() {
    local settings_file="$1"
    local editor_name="$2"

    if [ ! -f "$settings_file" ]; then
        info "$editor_name settings not found – skipping."
        return
    fi

    # Check if git.path is set to our wrapper
    local current_git_path
    current_git_path="$(python3 -c "
import json, re
with open('$settings_file') as f:
    content = f.read()
cleaned = re.sub(r',\s*([}\]])', r'\1', content)
d = json.loads(cleaned)
print(d.get('git.path', ''))
" 2>/dev/null || echo '')"

    if [ "$current_git_path" = "$WRAPPER_PATH" ]; then
        # Backup
        cp "$settings_file" "${settings_file}.backup.uninstall.$(date +%Y%m%d%H%M%S)"
        ok "Backed up $editor_name settings"

        # Remove git.path key
        python3 << PYEOF
import json, re

settings_file = "$settings_file"

with open(settings_file, 'r') as f:
    content = f.read()

cleaned = re.sub(r',\s*([}\]])', r'\1', content)

try:
    d = json.loads(cleaned)
except json.JSONDecodeError:
    print(f"Warning: Could not parse {settings_file}")
    exit(1)

if 'git.path' in d:
    del d['git.path']

with open(settings_file, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

PYEOF
        ok "Removed git.path from $editor_name settings"
    elif [ -n "$current_git_path" ]; then
        warn "$editor_name git.path is set to '$current_git_path' (not our wrapper). Leaving it alone."
    else
        info "$editor_name has no git.path set – nothing to remove."
    fi
}

remove_editor_git_path "$CURSOR_SETTINGS" "Cursor"
remove_editor_git_path "$ANTIGRAVITY_SETTINGS" "Antigravity IDE"

# ── Step 4: Audio files ─────────────────────────────────────────────────────
header "Step 4: Audio files"

if [ -d "$SOUNDS_DIR" ]; then
    info "Leaving $SOUNDS_DIR intact (contains your audio files)."
    info "To remove it manually:  rm -rf $SOUNDS_DIR"
else
    info "$SOUNDS_DIR not found – nothing to do."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
header "Uninstall Complete"

echo "The Git push producer tag has been removed."
echo ""
info "Actions taken:"
echo "  • Removed Git wrapper (if it was ours)"
echo "  • Removed PATH entry from .zshrc (if present)"
echo "  • Removed git.path from Cursor/Antigravity settings (if set to our wrapper)"
echo "  • Left ~/.git-sounds/ intact"
echo ""
info "Next steps:"
echo "  1. Open a new Terminal tab (or run: source ~/.zshrc)"
echo "  2. Restart Cursor and Antigravity IDE"
echo "  3. Verify: which git  (should show /opt/homebrew/bin/git or /usr/bin/git)"
echo ""
