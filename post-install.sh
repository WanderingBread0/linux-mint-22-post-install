#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  Linux Mint 22.x Post-Install Script                     ║
# ║  https://github.com/WanderingBread0/linux-mint-22-post-install ║
# ║                                                          ║
# ║  Installs:                                               ║
# ║    Browsers   : Brave Origins                            ║
# ║    Privacy    : Signal, Proton Mail, Proton VPN          ║
# ║    Dev        : VS Code, Git, GitHub CLI, Docker,        ║
# ║                 Node.js (nvm), Rust, Claude Code, tmux,  ║
# ║                 gum                                      ║
# ║    Media      : VLC, KDEnlive, SimpleScreenRecorder      ║
# ║    System     : Fastfetch, Flameshot, ClamTK,            ║
# ║                 Input Remapper, Solaar, RustDesk,        ║
# ║                 Kleopatra, NVIDIA 580 (if GPU detected)  ║
# ║    Hardware   : ROG Control Panel (AppImage)             ║
# ║    Games      : Steam                                    ║
# ║    Notes      : Standard Notes (AppImage)                ║
# ╚══════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR ]${NC}  $*"; }
step()  { echo -e "\n${BOLD}${CYAN}══ $* ${NC}"; }
ask()   { echo -e "${YELLOW}[>]${NC} $*"; }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# ── Preflight ─────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && { err "Run as a normal user with sudo, not as root."; exit 1; }

if ! grep -qiE "linuxmint|ubuntu" /etc/os-release 2>/dev/null; then
  warn "This script targets Linux Mint 22.x. Continue anyway? [y/N] "
  read -r ans; [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

UBUNTU_CODENAME=$(grep -oP '(?<=UBUNTU_CODENAME=)\S+' /etc/os-release 2>/dev/null || echo "noble")
ARCH=$(dpkg --print-architecture)

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗"
echo -e "║   Linux Mint 22.x — Post-Install Script      ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo ""
info "Running on: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
info "Ubuntu base: ${UBUNTU_CODENAME}  |  Arch: ${ARCH}"
echo ""

# ── 1. System Update ──────────────────────────────────────────
step "1/12  System Update"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gpg ca-certificates apt-transport-https software-properties-common lsb-release
ok "System up to date"

# ── 2. Add Repos ──────────────────────────────────────────────
step "2/12  Adding Third-Party Repositories"

## Brave Browser
if ! pkg_installed brave-origin && ! pkg_installed brave-browser; then
  info "Adding Brave repo..."
  curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
    | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
    | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
fi

## Signal Desktop
if ! pkg_installed signal-desktop; then
  info "Adding Signal repo..."
  curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] \
https://updates.signal.org/desktop/apt xenial main" \
    | sudo tee /etc/apt/sources.list.d/signal-xenial.list > /dev/null
fi

## Proton (Mail + VPN) — their release .deb adds the apt repo
if ! pkg_installed protonvpn-stable-release; then
  info "Adding Proton repo (via protonvpn-stable-release)..."
  PROTON_REL_DEB=$(mktemp /tmp/proton-release-XXXXXX.deb)
  curl -fsSL "https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb" \
    -o "$PROTON_REL_DEB"
  sudo dpkg -i "$PROTON_REL_DEB"
  rm -f "$PROTON_REL_DEB"
fi

## Docker
if ! pkg_installed docker-ce; then
  info "Adding Docker repo..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

## VS Code
if ! pkg_installed code; then
  info "Adding VS Code repo..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
fi

## GitHub CLI
if ! pkg_installed gh; then
  info "Adding GitHub CLI repo..."
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
fi

## Fastfetch PPA
if ! pkg_installed fastfetch; then
  info "Adding Fastfetch PPA..."
  sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
fi

## Charm (gum)
if ! pkg_installed gum; then
  info "Adding Charm repo (gum)..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
    | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
fi

ok "All repos added"

# ── 3. APT Install ────────────────────────────────────────────
step "3/12  Installing APT Packages"
sudo apt update
sudo apt install -y \
  brave-origin \
  signal-desktop \
  proton-mail \
  proton-vpn-gnome-desktop \
  code \
  git \
  gh \
  docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin \
  fastfetch \
  flameshot \
  clamtk \
  input-remapper \
  solaar \
  kleopatra \
  python3-pip \
  tmux \
  gum \
  vlc \
  kdenlive \
  simplescreenrecorder
ok "APT packages installed"

# ── 4. Steam ──────────────────────────────────────────────────
step "4/12  Steam"
if ! pkg_installed steam; then
  info "Enabling 32-bit architecture and installing Steam..."
  sudo dpkg --add-architecture i386
  sudo apt update
  # Accept Steam EULA non-interactively
  echo steam steam/question select "I AGREE" | sudo debconf-set-selections
  echo steam steam/license note '' | sudo debconf-set-selections
  sudo apt install -y steam
  ok "Steam installed"
else
  info "Steam already installed"
fi

# ── 5. NVIDIA Driver ──────────────────────────────────────────
step "5/12  NVIDIA Driver"
if lspci 2>/dev/null | grep -qiE "nvidia|geforce|quadro|tesla"; then
  if ! pkg_installed nvidia-driver-580-open; then
    info "NVIDIA GPU detected — installing driver 580 open..."
    sudo apt install -y nvidia-driver-580-open
    ok "NVIDIA driver 580 installed (reboot required)"
  else
    info "NVIDIA driver already installed"
  fi
else
  info "No NVIDIA GPU detected — skipping driver"
fi

# ── 6. Docker Post-Install ────────────────────────────────────
step "6/12  Docker Post-Install"
if ! groups "$USER" | grep -q '\bdocker\b'; then
  sudo usermod -aG docker "$USER"
  ok "Added $USER to docker group (active after next login)"
else
  info "Already in docker group"
fi
sudo systemctl enable --now docker containerd

# ── 7. nvm + Node.js LTS ──────────────────────────────────────
step "7/12  nvm + Node.js LTS"
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  info "Installing nvm..."
  NVM_VER=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VER}/install.sh" | bash
else
  info "nvm already installed"
fi
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
ok "Node.js $(node -v) active"

# ── 8. Rust ───────────────────────────────────────────────────
step "8/12  Rust (rustup)"
if ! command -v rustup &>/dev/null; then
  info "Installing rustup..."
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
# shellcheck source=/dev/null
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
rustup update stable
ok "Rust $(rustc --version)"

# ── 9. Claude Code CLI ────────────────────────────────────────
step "9/12  Claude Code CLI"
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code installed — run 'claude' to set it up"
else
  info "Claude Code already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
fi

# ── 10. RustDesk ──────────────────────────────────────────────
step "10/12  RustDesk"
if ! pkg_installed rustdesk; then
  info "Fetching latest RustDesk release..."
  RUSTDESK_URL=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | grep '"browser_download_url"' \
    | grep -E '".*x86-64.*\.deb"|".*x86_64.*\.deb"' \
    | grep -v 'flatpak\|rpm' \
    | head -1 | cut -d'"' -f4 || true)
  if [[ -n "$RUSTDESK_URL" ]]; then
    RUSTDESK_TMP=$(mktemp /tmp/rustdesk-XXXXXX.deb)
    curl -fsSL -o "$RUSTDESK_TMP" "$RUSTDESK_URL"
    sudo dpkg -i "$RUSTDESK_TMP" || sudo apt-get install -f -y
    rm -f "$RUSTDESK_TMP"
    ok "RustDesk installed"
  else
    warn "Could not fetch RustDesk — install manually: https://github.com/rustdesk/rustdesk/releases"
  fi
else
  info "RustDesk already installed"
fi

# ── 11. AppImages ─────────────────────────────────────────────
step "11/12  AppImages"
APPIMAGE_DIR="$HOME/.local/share/AppImages"
APP_DESKTOP="$HOME/.local/share/applications"
mkdir -p "$APPIMAGE_DIR" "$APP_DESKTOP"

_install_appimage() {
  local name="$1" dest="$2" url="$3" icon="$4" categories="$5"
  local desktop_file="${APP_DESKTOP}/${name,,}.desktop"
  if [[ ! -f "$dest" ]]; then
    if [[ -n "$url" ]]; then
      info "Downloading ${name}..."
      curl -fsSL -o "$dest" "$url"
      chmod +x "$dest"
      cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Name=${name}
Exec=${dest} --no-sandbox %U
Icon=${icon}
Type=Application
Categories=${categories}
StartupNotify=true
DESKTOP
      update-desktop-database "$APP_DESKTOP" 2>/dev/null || true
      ok "${name} installed → ${dest}"
    else
      warn "${name}: could not resolve download URL — install manually"
    fi
  else
    info "${name} already installed"
  fi
}

## Standard Notes
SN_URL=$(curl -fsSL https://api.github.com/repos/standardnotes/app/releases/latest \
  | grep '"browser_download_url"' \
  | grep -i 'linux-x86_64\.AppImage"' \
  | head -1 | cut -d'"' -f4 || true)
_install_appimage "Standard Notes" \
  "$APPIMAGE_DIR/StandardNotes.AppImage" \
  "$SN_URL" \
  "standard-notes" \
  "Office;Utility;"

## ROG Control Panel (AppImage — ASUS ROG)
ROG_URL=$(curl -fsSL https://api.github.com/repos/WanderingBread0/rog-control-panel/releases/latest \
  | grep '"browser_download_url"' \
  | grep '\.AppImage"' \
  | head -1 | cut -d'"' -f4 2>/dev/null || true)
_install_appimage "ROG Control Panel" \
  "$APPIMAGE_DIR/ROG-Control-Panel.AppImage" \
  "$ROG_URL" \
  "input-gaming" \
  "System;Settings;"

# ── 12. Login Setup ───────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗"
echo -e "║          ACCOUNT LOGIN SETUP                 ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  The following apps will open one at a time."
echo -e "  Log in to each before continuing to the next."
echo ""

_pause_for_app() {
  ask "Press Enter to open $1 (or Ctrl+C to skip all logins)..."
  read -r
}

## Proton VPN
step "  Proton VPN Login"
echo ""
info "Log in with your Proton account credentials."
info "If you have 2FA enabled (TOTP or hardware key), have it ready."
_pause_for_app "Proton VPN"
protonvpn-app &>/dev/null & disown
ok "Proton VPN launched — complete login, then come back here."
echo ""
ask "Press Enter once you've finished logging in to Proton VPN..."
read -r

## Proton Mail
step "  Proton Mail Login"
echo ""
info "Log in with your Proton account credentials."
info "2FA: have your authenticator app or hardware key ready."
_pause_for_app "Proton Mail"
proton-mail &>/dev/null & disown
ok "Proton Mail launched — complete login, then come back here."
echo ""
ask "Press Enter once you've finished logging in to Proton Mail..."
read -r

## Signal
step "  Signal Login"
echo ""
info "Signal links to your phone number."
info "  • New install : you'll be asked for your phone number and an SMS code."
info "  • Linked device: open Signal on your phone and scan the QR code shown."
info "  • Hardware 2FA : not supported by Signal — SMS or in-app confirm only."
_pause_for_app "Signal"
signal-desktop &>/dev/null & disown
ok "Signal launched — complete setup, then you're done."

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗"
echo -e "║        POST-INSTALL COMPLETE!                ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Recommended next steps:${NC}"
echo -e "   • ${YELLOW}Log out and back in${NC} — activates docker group membership"
echo -e "   • ${YELLOW}Run: claude${NC}            — complete Claude Code setup"
echo -e "   • ${YELLOW}Run: gh auth login${NC}     — authenticate GitHub CLI"
echo -e "   • Add to your ${YELLOW}~/.bashrc${NC} (or ~/.zshrc):"
echo -e "       export NVM_DIR=\"\$HOME/.nvm\""
echo -e "       [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\""
echo -e "       [ -f \"\$HOME/.cargo/env\" ] && . \"\$HOME/.cargo/env\""
echo ""
warn "A reboot is strongly recommended to apply the NVIDIA driver."
echo ""
ask "Reboot now? [y/N] "
read -r ans
[[ "$ans" =~ ^[Yy]$ ]] && sudo reboot || info "Reboot skipped — don't forget to reboot soon."
echo ""
