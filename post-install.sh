#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  Linux Mint 22.x Post-Install Script                     ║
# ║  https://github.com/WanderingBread0/linux-mint-22-post-install ║
# ║                                                          ║
# ║  Installs:                                               ║
# ║    Browsers   : Brave                                    ║
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

# NOTE: we deliberately do NOT use `set -e`.
# This is a convenience installer — one failed download or one unavailable
# package must NOT abort the whole run. Each step handles its own errors and
# the script continues, printing a summary of anything that failed at the end.
set -o pipefail

# ── Colours ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR ]${NC}  $*"; }
step()  { echo -e "\n${BOLD}${CYAN}══ $* ${NC}"; }
ask()   { echo -e "${YELLOW}[>]${NC} $*"; }

# Packages / steps that failed — reported in the final summary.
FAILED_ITEMS=()
note_fail() { FAILED_ITEMS+=("$1"); }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Read one line from the real terminal, so prompts work even when the script
# is run via `curl ... | bash` (where stdin is the script, not the keyboard).
tty_read() {  # tty_read VARNAME
  local __var="$1"
  if [[ -r /dev/tty ]]; then
    IFS= read -r "$__var" < /dev/tty || printf -v "$__var" '%s' ''
  else
    IFS= read -r "$__var" || printf -v "$__var" '%s' ''
  fi
}

# Run a command; log success/failure but NEVER abort the script.
run() {  # run "description" cmd args...
  local desc="$1"; shift
  if "$@"; then ok "$desc"; return 0; fi
  warn "$desc — failed (continuing)"; return 1
}

# Install apt packages one at a time so a single bad/unavailable package
# can't take the whole batch down with it.
apt_install() {
  local pkg
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      info "$pkg already installed"
      continue
    fi
    info "Installing $pkg ..."
    if sudo apt-get install -y "$pkg"; then
      ok "$pkg installed"
    else
      warn "Could not install $pkg — skipping"
      note_fail "apt: $pkg"
    fi
  done
}

# ── Preflight ─────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && { err "Run as a normal user with sudo, not as root."; exit 1; }

if ! command -v sudo &>/dev/null; then
  err "sudo is required but not installed."; exit 1
fi

if ! grep -qiE "linuxmint|ubuntu" /etc/os-release 2>/dev/null; then
  warn "This script targets Linux Mint 22.x. Continue anyway? [y/N] "
  tty_read ans; [[ "$ans" =~ ^[Yy]$ ]] || exit 0
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

# Cache sudo credentials up front so the long run doesn't stall on a prompt.
info "Requesting sudo access (you may be asked for your password)..."
sudo -v || { err "Could not obtain sudo access."; exit 1; }

# ── 1. System Update ──────────────────────────────────────────
step "1/12  System Update"
run "apt update" sudo apt-get update
run "apt upgrade" sudo apt-get upgrade -y
apt_install curl wget gpg ca-certificates apt-transport-https software-properties-common lsb-release
ok "System update step complete"

# ── 2. Add Repos ──────────────────────────────────────────────
step "2/12  Adding Third-Party Repositories"

## Brave Browser
if ! pkg_installed brave-browser; then
  info "Adding Brave repo..."
  if curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
       | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null; then
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
      | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
    ok "Brave repo added"
  else
    warn "Failed to add Brave repo"; note_fail "repo: Brave"
    sudo rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
  fi
fi

## Signal Desktop
if ! pkg_installed signal-desktop; then
  info "Adding Signal repo..."
  if curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
       | gpg --dearmor \
       | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null; then
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] \
https://updates.signal.org/desktop/apt xenial main" \
      | sudo tee /etc/apt/sources.list.d/signal-xenial.list > /dev/null
    ok "Signal repo added"
  else
    warn "Failed to add Signal repo"; note_fail "repo: Signal"
    sudo rm -f /usr/share/keyrings/signal-desktop-keyring.gpg
  fi
fi

## Proton VPN — their release .deb adds the apt repo.
## (Proton MAIL is NOT in this repo; it is installed from a standalone .deb in step 3.)
if ! pkg_installed protonvpn-stable-release; then
  info "Adding Proton VPN repo (via protonvpn-stable-release)..."
  PROTON_REL_DEB=$(mktemp /tmp/proton-release-XXXXXX.deb)
  if curl -fsSL "https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb" \
       -o "$PROTON_REL_DEB"; then
    sudo dpkg -i "$PROTON_REL_DEB" || sudo apt-get install -f -y
    ok "Proton VPN repo added"
  else
    warn "Failed to download Proton VPN release package"; note_fail "repo: Proton VPN"
  fi
  rm -f "$PROTON_REL_DEB"
fi

## Docker
if ! pkg_installed docker-ce; then
  info "Adding Docker repo..."
  sudo install -m 0755 -d /etc/apt/keyrings
  if curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" \
       | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    ok "Docker repo added"
  else
    warn "Failed to add Docker repo"; note_fail "repo: Docker"
    sudo rm -f /etc/apt/keyrings/docker.gpg
  fi
fi

## VS Code
if ! pkg_installed code; then
  info "Adding VS Code repo..."
  if curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
       | gpg --dearmor \
       | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null; then
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    ok "VS Code repo added"
  else
    warn "Failed to add VS Code repo"; note_fail "repo: VS Code"
    sudo rm -f /usr/share/keyrings/microsoft.gpg
  fi
fi

## GitHub CLI
if ! pkg_installed gh; then
  info "Adding GitHub CLI repo..."
  if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; then
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    ok "GitHub CLI repo added"
  else
    warn "Failed to add GitHub CLI repo"; note_fail "repo: GitHub CLI"
    sudo rm -f /usr/share/keyrings/githubcli-archive-keyring.gpg
  fi
fi

## Charm (gum)
if ! pkg_installed gum; then
  info "Adding Charm repo (gum)..."
  sudo install -m 0755 -d /etc/apt/keyrings
  if curl -fsSL https://repo.charm.sh/apt/gpg.key \
       | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg; then
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
      | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    ok "Charm repo added"
  else
    warn "Failed to add Charm repo"; note_fail "repo: Charm/gum"
    sudo rm -f /etc/apt/keyrings/charm.gpg
  fi
fi

## Fastfetch — try the PPA, but it's also in Ubuntu 24.04 'universe', so this is best-effort.
if ! pkg_installed fastfetch; then
  info "Adding Fastfetch PPA (best-effort)..."
  run "Fastfetch PPA" sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch || true
fi

ok "Repo step complete"

# ── 3. APT Install ────────────────────────────────────────────
step "3/12  Installing APT Packages"
# Refresh indices so the new repos are visible. Tolerate a non-zero exit:
# a single broken repo must not stop us from installing everything else.
run "apt update (post-repo)" sudo apt-get update || \
  warn "apt update reported errors — continuing; some repos may be unavailable"

apt_install \
  brave-browser \
  signal-desktop \
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

## Proton Mail — standalone .deb (no apt repo exists for it)
if ! command -v proton-mail &>/dev/null && ! pkg_installed proton-mail; then
  info "Installing Proton Mail (standalone .deb)..."
  PM_DEB=$(mktemp /tmp/protonmail-XXXXXX.deb)
  if curl -fsSL -o "$PM_DEB" "https://proton.me/download/mail/linux/ProtonMail-desktop-beta.deb"; then
    sudo apt-get install -y "$PM_DEB" || { sudo dpkg -i "$PM_DEB"; sudo apt-get install -f -y; }
    if command -v proton-mail &>/dev/null || pkg_installed proton-mail; then
      ok "Proton Mail installed"
    else
      warn "Proton Mail install may have failed"; note_fail "Proton Mail"
    fi
  else
    warn "Could not download Proton Mail .deb — skipping"; note_fail "Proton Mail"
  fi
  rm -f "$PM_DEB"
else
  info "Proton Mail already installed"
fi

ok "APT install step complete"

# ── 4. Steam ──────────────────────────────────────────────────
step "4/12  Steam"
if ! pkg_installed steam && ! pkg_installed steam-installer; then
  info "Enabling 32-bit architecture and installing Steam..."
  sudo dpkg --add-architecture i386
  run "apt update (i386)" sudo apt-get update
  # Accept Steam EULA non-interactively
  echo steam steam/question select "I AGREE" | sudo debconf-set-selections 2>/dev/null || true
  echo steam steam/license note '' | sudo debconf-set-selections 2>/dev/null || true
  # Mint ships 'steam-installer'; fall back to 'steam' on plain Ubuntu.
  apt_install steam-installer
  pkg_installed steam-installer || apt_install steam
  if pkg_installed steam-installer || pkg_installed steam; then ok "Steam installed"; fi
else
  info "Steam already installed"
fi

# ── 5. NVIDIA Driver ──────────────────────────────────────────
step "5/12  NVIDIA Driver"
if lspci 2>/dev/null | grep -qiE "nvidia|geforce|quadro|tesla"; then
  if ! pkg_installed nvidia-driver-580-open; then
    info "NVIDIA GPU detected — installing driver 580 open..."
    if apt_install nvidia-driver-580-open && pkg_installed nvidia-driver-580-open; then
      ok "NVIDIA driver 580 installed (reboot required)"
    else
      warn "nvidia-driver-580-open unavailable — run 'sudo ubuntu-drivers autoinstall' or use Driver Manager"
    fi
  else
    info "NVIDIA driver already installed"
  fi
else
  info "No NVIDIA GPU detected — skipping driver"
fi

# ── 6. Docker Post-Install ────────────────────────────────────
step "6/12  Docker Post-Install"
if pkg_installed docker-ce; then
  if ! groups "$USER" | grep -q '\bdocker\b'; then
    run "Add $USER to docker group" sudo usermod -aG docker "$USER" \
      && ok "Added $USER to docker group (active after next login)"
  else
    info "Already in docker group"
  fi
  run "Enable docker + containerd" sudo systemctl enable --now docker containerd
else
  info "Docker not installed — skipping post-install"
fi

# ── 7. nvm + Node.js LTS ──────────────────────────────────────
step "7/12  nvm + Node.js LTS"
export NVM_DIR="$HOME/.nvm"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  info "Installing nvm..."
  NVM_VER=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  [[ -z "$NVM_VER" ]] && NVM_VER="0.40.1"   # fallback if GitHub API is rate-limited
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VER}/install.sh" | bash \
    || { warn "nvm install failed"; note_fail "nvm"; }
else
  info "nvm already installed"
fi
# shellcheck source=/dev/null
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
  if nvm install --lts && nvm use --lts; then
    ok "Node.js $(node -v 2>/dev/null) active"
  else
    warn "Node.js install failed"; note_fail "Node.js (nvm)"
  fi
else
  warn "nvm not available — skipping Node.js"; note_fail "Node.js (nvm)"
fi

# ── 8. Rust ───────────────────────────────────────────────────
step "8/12  Rust (rustup)"
if ! command -v rustup &>/dev/null && [[ ! -f "$HOME/.cargo/bin/rustup" ]]; then
  info "Installing rustup..."
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    || { warn "rustup install failed"; note_fail "Rust"; }
fi
# shellcheck source=/dev/null
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
if command -v rustup &>/dev/null; then
  run "rustup update stable" rustup update stable
  ok "Rust $(rustc --version 2>/dev/null)"
else
  warn "Rust not available"; note_fail "Rust"
fi

# ── 9. Claude Code CLI ────────────────────────────────────────
step "9/12  Claude Code CLI"
if ! command -v claude &>/dev/null; then
  if command -v npm &>/dev/null; then
    if npm install -g @anthropic-ai/claude-code; then
      ok "Claude Code installed — run 'claude' to set it up"
    else
      warn "Claude Code install failed"; note_fail "Claude Code"
    fi
  else
    warn "npm not available (Node.js step may have failed) — skipping Claude Code"
    note_fail "Claude Code (no npm)"
  fi
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
    if curl -fsSL -o "$RUSTDESK_TMP" "$RUSTDESK_URL"; then
      sudo apt-get install -y "$RUSTDESK_TMP" || { sudo dpkg -i "$RUSTDESK_TMP"; sudo apt-get install -f -y; }
      pkg_installed rustdesk && ok "RustDesk installed" || { warn "RustDesk install failed"; note_fail "RustDesk"; }
    else
      warn "RustDesk download failed"; note_fail "RustDesk"
    fi
    rm -f "$RUSTDESK_TMP"
  else
    warn "Could not resolve RustDesk URL — install manually: https://github.com/rustdesk/rustdesk/releases"
    note_fail "RustDesk"
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
  desktop_file="${desktop_file// /-}"
  if [[ -f "$dest" ]]; then
    info "${name} already installed"
    return 0
  fi
  if [[ -z "$url" ]]; then
    warn "${name}: could not resolve download URL — install manually"
    note_fail "$name (AppImage URL)"
    return 1
  fi
  info "Downloading ${name}..."
  if curl -fsSL -o "$dest" "$url"; then
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
    warn "${name}: download failed"
    note_fail "$name (AppImage)"
    rm -f "$dest"
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
echo -e "  Installed apps will open one at a time."
echo -e "  Log in to each before continuing to the next."
echo ""

# Launch an app for login only if it actually got installed.
_login_app() {  # _login_app "Display Name" command-name extra-info...
  local title="$1" cmd="$2"; shift 2
  step "  ${title} Login"
  echo ""
  if ! command -v "$cmd" &>/dev/null; then
    warn "${title} is not installed — skipping login."
    return 0
  fi
  local line
  for line in "$@"; do info "$line"; done
  ask "Press Enter to open ${title} (or just press Enter to skip)..."
  local _x; tty_read _x
  "$cmd" &>/dev/null & disown
  ok "${title} launched — complete login, then return here."
  echo ""
  ask "Press Enter once you've finished logging in to ${title}..."
  tty_read _x
}

_login_app "Proton VPN" protonvpn-app \
  "Log in with your Proton account credentials." \
  "If you have 2FA enabled (TOTP or hardware key), have it ready."

_login_app "Proton Mail" proton-mail \
  "Log in with your Proton account credentials." \
  "2FA: have your authenticator app or hardware key ready."

_login_app "Signal" signal-desktop \
  "Signal links to your phone number." \
  "  • New install : you'll be asked for your phone number and an SMS code." \
  "  • Linked device: open Signal on your phone and scan the QR code shown." \
  "  • Hardware 2FA : not supported by Signal — SMS or in-app confirm only."

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗"
echo -e "║        POST-INSTALL COMPLETE!                ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo ""

if ((${#FAILED_ITEMS[@]})); then
  warn "The following items did NOT install cleanly:"
  for item in "${FAILED_ITEMS[@]}"; do echo -e "   ${RED}✗${NC} $item"; done
  echo -e "  You can re-run this script to retry them, or install them manually."
  echo ""
fi

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
tty_read ans
[[ "$ans" =~ ^[Yy]$ ]] && sudo reboot || info "Reboot skipped — don't forget to reboot soon."
echo ""
