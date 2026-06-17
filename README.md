# Linux Mint 22.x Post-Install Script

A single script that takes a fresh Linux Mint 22.x install to fully set up — browsers, privacy tools, dev environment, media apps, system utilities, and games. Runs hands-off as much as possible, then walks you through logging in to each account-based app.

## What gets installed

| Category | Apps |
|----------|------|
| **Browser** | Brave (Origins channel) |
| **Privacy** | Signal, Proton Mail, Proton VPN |
| **Dev** | VS Code, Git, GitHub CLI, Docker (CE + Compose + Buildx), Node.js via nvm, Rust via rustup, Claude Code CLI, tmux, gum |
| **Media** | VLC, KDEnlive, SimpleScreenRecorder |
| **Notes** | Standard Notes (AppImage) |
| **System** | Fastfetch, Flameshot, ClamTK, Input Remapper, Solaar, RustDesk, Kleopatra, NVIDIA driver 580 (auto-detected) |
| **Hardware** | ROG Control Panel (AppImage — ASUS ROG laptops) |
| **Games** | Steam |

## Requirements

- Linux Mint 22.x (Ubuntu 24.04 Noble base)
- A user account with `sudo` access
- Internet connection

## Usage

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/WanderingBread0/linux-mint-22-post-install/main/post-install.sh -o post-install.sh

# Make executable
chmod +x post-install.sh

# Run
./post-install.sh
```

Or in one line:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WanderingBread0/linux-mint-22-post-install/main/post-install.sh)
```

> **Do not run with `sudo`** — the script calls `sudo` itself where needed.

## What to expect

The script runs in 12 steps and takes 10–20 minutes depending on your connection. Most of it is fully automated. At the end, it opens Proton VPN, Proton Mail, and Signal one at a time and pauses so you can log in to each before the next opens.

**For 2FA:** Proton apps support TOTP and hardware keys (YubiKey etc.) — have your device ready when the login prompt appears. Signal uses SMS or in-app QR scan from your phone.

## After the script finishes

Add these lines to your `~/.bashrc` (or `~/.zshrc`) so nvm and Cargo are available in new terminals:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
```

Then:

```bash
source ~/.bashrc   # or open a new terminal
claude             # set up Claude Code
gh auth login      # authenticate GitHub CLI
```

A reboot is recommended to activate the NVIDIA driver and Docker group membership. The script will prompt you.

## Notes

- **Idempotent** — safe to re-run. Already-installed packages and repos are skipped.
- **NVIDIA driver** — only installs if an NVIDIA GPU is detected via `lspci`.
- **ROG Control Panel** — only relevant for ASUS ROG laptops. The AppImage is pulled from the [rog-control-panel](https://github.com/WanderingBread0/rog-control-panel) repo's latest release. If no release exists, the script skips it with a link.
- **RustDesk** — fetches the latest `.deb` directly from the [rustdesk](https://github.com/rustdesk/rustdesk/releases) GitHub releases page.
- **Standard Notes** — fetches the latest AppImage from the [standardnotes/app](https://github.com/standardnotes/app/releases) GitHub releases page.

## Tested on

- Linux Mint 22.3 (Virginia) — Cinnamon edition
