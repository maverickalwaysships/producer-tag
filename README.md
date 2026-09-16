# 🎵 Git Push Producer Tag

A lightweight, transparent Git wrapper that plays your **producer tag audio** after every successful `git push` — in Terminal, Cursor, and Antigravity IDE.

---

## What it does

Every time you run `git push`, the wrapper:

1. Forwards the command to the real Git binary (no behaviour change)
2. On success — and only if the subcommand is `push` — plays your MP3 tag via `afplay`
3. Preserves all exit codes, stdout, and stderr exactly

The audio plays in the background so it never blocks your workflow.

---

## Requirements

- macOS (uses `afplay` for audio playback)
- Git (Homebrew or system)
- `zsh` as your shell
- An MP3 file for your producer tag

---

## Quick start

```bash
# 1. Clone the repo
git clone git@github-personal:maverickalwaysships/producer-tag.git
cd producer-tag

# 2. Copy and edit the environment config
cp .env.example .env
#    Open .env and adjust any paths if your setup differs from the defaults.

# 3. Place your producer tag MP3
#    Default path (from .env): $HOME/.git-sounds/push.mp3
mkdir -p ~/.git-sounds
cp /path/to/your/tag.mp3 ~/.git-sounds/push.mp3

# 4. Run the setup
bash setup-git-push-tag.sh

# 5. Open a new terminal tab (or reload your shell)
source ~/.zshrc
```

---

## Configuration

All paths are controlled by `.env`. Copy `.env.example` to `.env` and edit:

| Variable              | Default                                                          | Purpose                                      |
|-----------------------|------------------------------------------------------------------|----------------------------------------------|
| `WRAPPER_DIR`         | `$HOME/.local/bin`                                               | Where the Git wrapper script is installed    |
| `WRAPPER_PATH`        | `$HOME/.local/bin/git`                                           | Full path to the wrapper                     |
| `SOUNDS_DIR`          | `$HOME/.git-sounds`                                              | Directory for audio files                    |
| `AUDIO_FILE`          | `$HOME/.git-sounds/push.mp3`                                     | Your producer tag MP3                        |
| `ZSHRC`               | `$HOME/.zshrc`                                                   | Shell config (PATH is added here)            |
| `CURSOR_SETTINGS`     | `$HOME/Library/Application Support/Cursor/User/settings.json`    | Cursor editor git.path                       |
| `ANTIGRAVITY_SETTINGS`| `$HOME/Library/Application Support/Antigravity IDE/User/settings.json` | Antigravity IDE git.path            |

> **Note:** `.env` is listed in `.gitignore` and will never be committed. Only `.env.example` is tracked.

---

## Scripts

| Script                      | Purpose                                                    |
|-----------------------------|------------------------------------------------------------|
| `setup-git-push-tag.sh`     | Installs the wrapper and configures editors                |
| `diagnose-git-push-tag.sh`  | Verifies the setup — run this if something seems off       |
| `uninstall-git-push-tag.sh` | Cleanly removes the wrapper and restores original config   |

---

## How the wrapper works

```
git push  →  ~/.local/bin/git (wrapper)
                 │
                 ├─ forwards all args to real Git (/opt/homebrew/bin/git)
                 │
                 └─ on exit 0 + subcommand == "push"
                        └─ afplay ~/.git-sounds/push.mp3 &
```

The wrapper is a plain Bash script — no daemons, no background services, no network calls.

---

## Diagnostics

If the tag isn't playing, run:

```bash
bash diagnose-git-push-tag.sh
```

This checks the wrapper, the real Git path, audio file presence, PATH order, and editor config.

---

## Uninstall

```bash
bash uninstall-git-push-tag.sh
source ~/.zshrc
```

This removes the wrapper, cleans the `.zshrc` PATH entry, and restores `git.path` in your editors. Your audio files in `~/.git-sounds/` are left untouched.

---

## Security

- No secrets or personal paths are stored in this repository
- `.env` (machine-specific paths) is in `.gitignore`
- `audio/` (personal audio files) is in `.gitignore`
- The wrapper script does not make any network requests

---

## License

MIT
