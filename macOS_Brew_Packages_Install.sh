#!/usr/bin/env bash
# macOS setup script — Homebrew + apps + TouchID sudo

set -uo pipefail

# ─────────────────────────────────────────────────────────
# COLOURS
# ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { printf '%b\n' "${BLUE}${BOLD}[INFO]${RESET}  $*"; }
success() { printf '%b\n' "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { printf '%b\n' "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { printf '%b\n' "${RED}${BOLD}[ERROR]${RESET} $*"; }

# ─────────────────────────────────────────────────────────
# INSTALL TARGETS  (defined early so we can count them)
# ─────────────────────────────────────────────────────────
CASKS=(
    adobe-acrobat-reader
    calibre
    coteditor
    github
    google-chrome
    google-gemini
    macs-fan-control
    visual-studio-code
    vlc
    podman-desktop
    utm
)

FORMULAE=(
    python3
    vim
    gh
)

TOTAL_STEPS=$(( ${#CASKS[@]} + ${#FORMULAE[@]} ))
CURRENT_STEP=0

# ─────────────────────────────────────────────────────────
# PROGRESS BAR
# ─────────────────────────────────────────────────────────
print_progress() {
    local label="$1"
    local bar_width=50
    local filled=0 pct=0

    if [[ $TOTAL_STEPS -gt 0 && $CURRENT_STEP -gt 0 ]]; then
        pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
        filled=$(( CURRENT_STEP * bar_width / TOTAL_STEPS ))
    fi
    local empty=$(( bar_width - filled ))

    local bar_filled="" bar_empty=""
    for (( i=0; i<filled; i++ )); do bar_filled+="█"; done
    for (( i=0; i<empty;  i++ )); do bar_empty+="░"; done

    printf "\n  ${BOLD}[${GREEN}%s${RESET}${BOLD}%s] %3d%% (%d/%d)${RESET}\n" \
        "$bar_filled" "$bar_empty" "$pct" "$CURRENT_STEP" "$TOTAL_STEPS"
    printf "  ${YELLOW}${BOLD}▶  %s${RESET}\n\n" "$label"
}

# ─────────────────────────────────────────────────────────
# MUST RUN ON MACOS
# ─────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is for macOS only."
    exit 1
fi

printf '\n'
printf '%b\n' "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
printf '%b\n' "${BOLD}║        macOS Setup — install_macOS_progs.sh      ║${RESET}"
printf '%b\n' "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
printf '\n'

# ─────────────────────────────────────────────────────────
# 1. ENABLE TOUCHID FOR SUDO
# ─────────────────────────────────────────────────────────
info "Enabling TouchID for sudo operations..."

PAM_SUDO="/etc/pam.d/sudo"
TOUCHID_LINE="auth       sufficient     pam_tid.so"

if grep -q "pam_tid.so" "$PAM_SUDO" 2>/dev/null; then
    success "TouchID for sudo is already enabled."
else
    PAM_SUDO_LOCAL="/etc/pam.d/sudo_local"
    if [[ -f "$PAM_SUDO_LOCAL" ]]; then
        if grep -q "pam_tid.so" "$PAM_SUDO_LOCAL" 2>/dev/null; then
            success "TouchID for sudo already enabled in sudo_local."
        else
            echo "$TOUCHID_LINE" | sudo tee -a "$PAM_SUDO_LOCAL" > /dev/null
            success "TouchID for sudo enabled in $PAM_SUDO_LOCAL."
        fi
    else
        if [[ -f "${PAM_SUDO_LOCAL}.template" ]]; then
            sudo cp "${PAM_SUDO_LOCAL}.template" "$PAM_SUDO_LOCAL"
            sudo sed -i '' "s/#auth/auth/" "$PAM_SUDO_LOCAL"
            success "TouchID for sudo enabled via sudo_local template."
        else
            sudo sed -i '' "1a\\
$TOUCHID_LINE
" "$PAM_SUDO" 2>/dev/null || {
                warn "Could not patch $PAM_SUDO automatically."
                warn "To enable TouchID manually, add this line to $PAM_SUDO after line 1:"
                warn "  $TOUCHID_LINE"
            }
            success "TouchID for sudo patched into $PAM_SUDO."
        fi
    fi
fi

echo ""

# ─────────────────────────────────────────────────────────
# 2. INSTALL HOMEBREW
# ─────────────────────────────────────────────────────────
info "Checking for Homebrew..."

if command -v brew &>/dev/null; then
    success "Homebrew already installed at $(brew --prefix)."
    info "Updating Homebrew..."
    brew update --quiet
    success "Homebrew updated."
else
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        PROFILE="$HOME/.zprofile"
        if ! grep -q "homebrew/bin/brew shellenv" "$PROFILE" 2>/dev/null; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$PROFILE"
            info "Added brew to $PROFILE for future sessions."
        fi
    fi
    success "Homebrew installed."
fi

echo ""

# ─────────────────────────────────────────────────────────
# 3. CASKS (GUI APPLICATIONS)
# ─────────────────────────────────────────────────────────
info "Installing ${#CASKS[@]} GUI applications via brew install --cask ..."

for cask in "${CASKS[@]}"; do
    print_progress "Installing cask: $cask"
    if brew list --cask "$cask" &>/dev/null; then
        success "$cask is already installed — skipping."
    else
        if brew install --cask "$cask"; then
            success "$cask installed."
        else
            warn "$cask installation failed or was skipped. Check the output above."
        fi
    fi
    (( CURRENT_STEP++ )) || true
done

echo ""

# ─────────────────────────────────────────────────────────
# 4. FORMULAE (CLI TOOLS)
# ─────────────────────────────────────────────────────────
info "Installing ${#FORMULAE[@]} CLI tools via brew install ..."

for formula in "${FORMULAE[@]}"; do
    print_progress "Installing formula: $formula"
    if brew list "$formula" &>/dev/null; then
        success "$formula is already installed — skipping."
    else
        if brew install "$formula"; then
            success "$formula installed."
        else
            warn "$formula installation failed. Check the output above."
        fi
    fi
    (( CURRENT_STEP++ )) || true
done

# Final 100% bar
print_progress "All packages processed ✔"

# ─────────────────────────────────────────────────────────
# 5. PIP PACKAGES
# ─────────────────────────────────────────────────────────
printf '\n'
info "Installing pip packages with --break-system-packages ..."

PYTHON_BIN="$(brew --prefix)/bin/python3"
PIP_BIN="$(brew --prefix)/bin/pip3"

# Configure pip globally so it never prompts for pipx/venv
PIP_CONF_DIR="$HOME/Library/Application Support/pip"
PIP_CONF_FILE="$PIP_CONF_DIR/pip.conf"
mkdir -p "$PIP_CONF_DIR"
if grep -q "break-system-packages" "$PIP_CONF_FILE" 2>/dev/null; then
    success "pip.conf already configured — no venv/pipx prompts."
else
    cat >> "$PIP_CONF_FILE" <<'EOF'
[global]
break-system-packages = true
EOF
    success "pip.conf updated — pip will never ask you to use pipx or a venv."
fi

# Ensure pip is up to date
"$PYTHON_BIN" -m pip install --upgrade pip --break-system-packages --quiet \
    && success "pip upgraded." \
    || warn "pip upgrade failed — continuing anyway."

PIP_PACKAGES=(
    playwright
)

for pkg in "${PIP_PACKAGES[@]}"; do
    if "$PIP_BIN" show "$pkg" &>/dev/null; then
        success "$pkg is already installed — skipping."
    else
        info "Installing $pkg ..."
        if "$PIP_BIN" install "$pkg" --break-system-packages; then
            success "$pkg installed."
        else
            warn "$pkg installation failed. Check the output above."
        fi
    fi
done

# Install Playwright browsers (chromium, firefox, webkit)
if command -v playwright &>/dev/null || "$PYTHON_BIN" -m playwright --version &>/dev/null 2>&1; then
    info "Installing Playwright browsers..."
    "$PYTHON_BIN" -m playwright install \
        && success "Playwright browsers installed." \
        || warn "Playwright browser install failed. Run: python3 -m playwright install"
fi

# ─────────────────────────────────────────────────────────
# 5. SUMMARY
# ─────────────────────────────────────────────────────────
printf '%b\n' "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
printf '%b\n' "${BOLD}║                   Summary                        ║${RESET}"
printf '%b\n' "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
printf '\n'

printf '%b\n' "${BOLD}TouchID for sudo:${RESET}"
if grep -q "pam_tid.so" /etc/pam.d/sudo /etc/pam.d/sudo_local 2>/dev/null; then
    success "Enabled"
else
    warn "Not confirmed — check /etc/pam.d/sudo or /etc/pam.d/sudo_local"
fi

printf '\n'
printf '%b\n' "${BOLD}Installed applications:${RESET}"
for cask in "${CASKS[@]}"; do
    brew list --cask "$cask" &>/dev/null \
        && printf '  %b\n' "${GREEN}✔${RESET}  $cask" \
        || printf '  %b\n' "${RED}✘${RESET}  $cask  (check manually)"
done

printf '\n'
printf '%b\n' "${BOLD}Installed CLI tools:${RESET}"
for formula in "${FORMULAE[@]}"; do
    brew list "$formula" &>/dev/null \
        && printf '  %b\n' "${GREEN}✔${RESET}  $formula  ($(brew list --versions "$formula"))" \
        || printf '  %b\n' "${RED}✘${RESET}  $formula  (check manually)"
done

echo ""
info "Python version: $(python3 --version 2>/dev/null || echo 'not found in PATH')"
info "Vim version:    $(vim --version 2>/dev/null | head -1 || echo 'not found in PATH')"

printf '\n'
printf '%b\n' "${BOLD}Installed pip packages:${RESET}"
for pkg in "${PIP_PACKAGES[@]}"; do
    "$PIP_BIN" show "$pkg" &>/dev/null \
        && printf '  %b\n' "${GREEN}✔${RESET}  $pkg  ($("$PIP_BIN" show "$pkg" 2>/dev/null | grep ^Version | awk '{print $2}'))" \
        || printf '  %b\n' "${RED}✘${RESET}  $pkg  (check manually)"
done

echo ""
success "Setup complete."
