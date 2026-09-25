#!/usr/bin/env bash
# macOS setup script — Homebrew + apps + TouchID sudo

# On first invocation (any shell): re-exec under bash and pipe through tee for logging.
# This means sh, zsh, fish, etc. all work — bash is invoked transparently.
if [ -z "${_MACSETUP_RUN:-}" ]; then
    _LOG="$HOME/macOS_setup_$(date +%Y%m%d_%H%M%S).log"
    export _MACSETUP_RUN=1 _MACSETUP_LOG="$_LOG"
    # Use `script` to allocate a pseudo-TTY so brew/curl keep their LIVE download
    # progress (download size + %), while still capturing everything to $_LOG.
    # Piping through `tee` (below) hides that progress because brew detects it is
    # writing to a pipe rather than a terminal.
    if command -v script >/dev/null 2>&1; then
        script -q "$_LOG" bash "$0" "$@"
    else
        bash "$0" "$@" 2>&1 | tee -a "$_LOG"
    fi
    exit $?
fi

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
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────
DRY_RUN=false

show_help() {
    printf '%b\n' "${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]"
    printf '\n'
    printf '%b\n' "${BOLD}Options:${RESET}"
    printf '  --dry-run    Print what would be installed without making any changes\n'
    printf '  --help, -h   Show this help message\n'
    printf '\n'
    printf '%b\n' "${BOLD}What this script does:${RESET}"
    printf '  1. Checks for Xcode Command Line Tools\n'
    printf '  2. Enables TouchID for sudo\n'
    printf '  3. Installs / updates Homebrew\n'
    printf '  4. Installs GUI apps (casks)\n'
    printf '  5. Installs CLI tools (formulae)\n'
    printf '  6. Installs pip packages\n'
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h) show_help; exit 0 ;;
        *) error "Unknown argument: $arg"; show_help; exit 1 ;;
    esac
done

# ─────────────────────────────────────────────────────────
# INSTALL TARGETS  (defined early so we can count them)
# ─────────────────────────────────────────────────────────
CASKS=(
    adobe-acrobat-reader
    calibre
    caskhub
    coteditor
    drawio
    github
    github-copilot-app
    google-chrome
    google-gemini
    lm-studio
    macs-fan-control
    omnidisksweeper
    podman-desktop
    utm
    visual-studio-code
    vlc
    zoom
)

FORMULAE=(
    brotli
    ca-certificates
    curl
    gettext
    gh
    git
    json-c
    libidn2
    libnghttp2
    libnghttp3
    libngtcp2
    libpsl
    libsodium
    libssh2
    libunistring
    lz4
    mpdecimal
    ncurses
    openssl@3
    openssl@4
    pcre2
    python@3.14
    readline
    sqlite
    vim
    wget
    xz
    zstd
)

TOTAL_STEPS=$(( ${#CASKS[@]} + ${#FORMULAE[@]} ))
CURRENT_STEP=0

# Failed install tracking
FAILED_CASKS=()
FAILED_FORMULAE=()
FAILED_PIPS=()

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

# ─────────────────────────────────────────────────────────
# MACOS VERSION CHECK (minimum: 12 Monterey)
# ─────────────────────────────────────────────────────────
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [[ $MACOS_MAJOR -lt 12 ]]; then
    error "macOS 12 (Monterey) or later is required. Found: $(sw_vers -productVersion)"
    exit 1
fi

printf '\n'
printf '%b\n' "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
printf '%b\n' "${BOLD}║        macOS Setup — install_macOS_progs.sh      ║${RESET}"
printf '%b\n' "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
printf '\n'

# ─────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────
LOG_FILE="${_MACSETUP_LOG}"
info "Logging session to $LOG_FILE"

$DRY_RUN && warn "DRY RUN MODE — no changes will be made."

echo ""

# ─────────────────────────────────────────────────────────
# 1. XCODE COMMAND LINE TOOLS
# ─────────────────────────────────────────────────────────
info "Checking for Xcode Command Line Tools..."

if xcode-select -p &>/dev/null; then
    success "Xcode Command Line Tools already installed at $(xcode-select -p)."
else
    if $DRY_RUN; then
        info "[DRY RUN] Would trigger Xcode Command Line Tools installation."
    else
        info "Xcode Command Line Tools not found — triggering installer..."
        xcode-select --install 2>/dev/null || true
        warn "A system dialog has appeared to install Xcode Command Line Tools."
        warn "Complete that installation, then re-run this script."
        exit 1
    fi
fi

echo ""

# ─────────────────────────────────────────────────────────
# 2. ENABLE TOUCHID FOR SUDO
# ─────────────────────────────────────────────────────────
info "Enabling TouchID for sudo operations..."

PAM_SUDO="/etc/pam.d/sudo"
TOUCHID_LINE="auth       sufficient     pam_tid.so"

if grep -q "pam_tid.so" "$PAM_SUDO" 2>/dev/null; then
    success "TouchID for sudo is already enabled."
else
    PAM_SUDO_LOCAL="/etc/pam.d/sudo_local"
    if $DRY_RUN; then
        info "[DRY RUN] Would enable TouchID for sudo in $PAM_SUDO_LOCAL."
    elif [[ -f "$PAM_SUDO_LOCAL" ]]; then
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
# 3. INSTALL HOMEBREW
# ─────────────────────────────────────────────────────────
info "Checking for Homebrew..."

if command -v brew &>/dev/null; then
    success "Homebrew already installed at $(brew --prefix)."
    if $DRY_RUN; then
        info "[DRY RUN] Would run: brew update && brew upgrade"
    else
        info "Updating Homebrew..."
        brew update --quiet
        success "Homebrew updated."
    fi
else
    if $DRY_RUN; then
        info "[DRY RUN] Would install Homebrew."
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
fi

echo ""

# ─────────────────────────────────────────────────────────
# 4. CASKS (GUI APPLICATIONS)
# ─────────────────────────────────────────────────────────
info "Installing ${#CASKS[@]} GUI applications via brew install --cask ..."

for cask in "${CASKS[@]}"; do
    print_progress "Installing cask: $cask"
    if $DRY_RUN; then
        info "[DRY RUN] Would install cask: $cask"
    elif brew list --cask "$cask" &>/dev/null; then
        if [[ -n "$(brew outdated --cask --quiet "$cask" 2>/dev/null)" ]]; then
            brew upgrade --cask --verbose "$cask" && success "$cask upgraded."
        else
            success "$cask already at latest version — skipping upgrade."
        fi
    else
        if brew install --cask --verbose "$cask"; then
            success "$cask installed."
        else
            warn "$cask installation failed or was skipped. Check the output above."
            FAILED_CASKS+=("$cask")
        fi
    fi
    (( CURRENT_STEP++ )) || true
done

echo ""

# ─────────────────────────────────────────────────────────
# 5. FORMULAE (CLI TOOLS)
# ─────────────────────────────────────────────────────────
info "Installing ${#FORMULAE[@]} CLI tools via brew install ..."

for formula in "${FORMULAE[@]}"; do
    print_progress "Installing formula: $formula"
    if $DRY_RUN; then
        info "[DRY RUN] Would install formula: $formula"
    elif brew list "$formula" &>/dev/null; then
        if [[ -n "$(brew outdated --quiet "$formula" 2>/dev/null)" ]]; then
            brew upgrade --verbose "$formula" && success "$formula upgraded."
        else
            success "$formula already at latest version — skipping upgrade."
        fi
    else
        if brew install --verbose "$formula"; then
            success "$formula installed."
        else
            warn "$formula installation failed. Check the output above."
            FAILED_FORMULAE+=("$formula")
        fi
    fi
    (( CURRENT_STEP++ )) || true
done

# Final 100% bar
print_progress "All packages processed ✔"

# ─────────────────────────────────────────────────────────
# 6. PIP PACKAGES
# ─────────────────────────────────────────────────────────
printf '\n'
info "Installing pip packages with --break-system-packages ..."

PYTHON_BIN="$(brew --prefix)/bin/python3"
PIP_BIN="$(brew --prefix)/bin/pip3"

if ! $DRY_RUN; then
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
fi

PIP_PACKAGES=(
    playwright
)

for pkg in "${PIP_PACKAGES[@]}"; do
    if $DRY_RUN; then
        info "[DRY RUN] Would install pip package: $pkg"
    elif "$PIP_BIN" show "$pkg" &>/dev/null; then
        if "$PIP_BIN" list --outdated 2>/dev/null | grep -q "^$pkg "; then
            "$PIP_BIN" install --upgrade "$pkg" --break-system-packages \
                && success "$pkg upgraded." || warn "$pkg upgrade failed."
        else
            success "$pkg already at latest version — skipping upgrade."
        fi
    else
        info "Installing $pkg ..."
        if "$PIP_BIN" install "$pkg" --break-system-packages; then
            success "$pkg installed."
        else
            warn "$pkg installation failed. Check the output above."
            FAILED_PIPS+=("$pkg")
        fi
    fi
done

if ! $DRY_RUN; then
    # Install Playwright browsers (chromium, firefox, webkit)
    if command -v playwright &>/dev/null || "$PYTHON_BIN" -m playwright --version &>/dev/null 2>&1; then
        info "Installing Playwright browsers..."
        "$PYTHON_BIN" -m playwright install \
            && success "Playwright browsers installed." \
            || warn "Playwright browser install failed. Run: python3 -m playwright install"
    fi
fi

# ─────────────────────────────────────────────────────────
# 7. SUMMARY
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
    if $DRY_RUN; then
        printf '  %b\n' "${YELLOW}?${RESET}  $cask  (dry run)"
    else
        brew list --cask "$cask" &>/dev/null \
            && printf '  %b\n' "${GREEN}✔${RESET}  $cask" \
            || printf '  %b\n' "${RED}✘${RESET}  $cask  (check manually)"
    fi
done

printf '\n'
printf '%b\n' "${BOLD}Installed CLI tools:${RESET}"
for formula in "${FORMULAE[@]}"; do
    if $DRY_RUN; then
        printf '  %b\n' "${YELLOW}?${RESET}  $formula  (dry run)"
    else
        brew list "$formula" &>/dev/null \
            && printf '  %b\n' "${GREEN}✔${RESET}  $formula  ($(brew list --versions "$formula"))" \
            || printf '  %b\n' "${RED}✘${RESET}  $formula  (check manually)"
    fi
done

if ! $DRY_RUN; then
    echo ""
    info "Python version: $(python3 --version 2>/dev/null || echo 'not found in PATH')"
    info "Vim version:    $(vim --version 2>/dev/null | head -1 || echo 'not found in PATH')"
fi

printf '\n'
printf '%b\n' "${BOLD}Installed pip packages:${RESET}"
for pkg in "${PIP_PACKAGES[@]}"; do
    if $DRY_RUN; then
        printf '  %b\n' "${YELLOW}?${RESET}  $pkg  (dry run)"
    else
        "$PIP_BIN" show "$pkg" &>/dev/null \
            && printf '  %b\n' "${GREEN}✔${RESET}  $pkg  ($("$PIP_BIN" show "$pkg" 2>/dev/null | grep ^Version | awk '{print $2}'))" \
            || printf '  %b\n' "${RED}✘${RESET}  $pkg  (check manually)"
    fi
done

# Failed installs summary
if [[ ${#FAILED_CASKS[@]} -gt 0 || ${#FAILED_FORMULAE[@]} -gt 0 || ${#FAILED_PIPS[@]} -gt 0 ]]; then
    printf '\n'
    printf '%b\n' "${RED}${BOLD}Failed installations:${RESET}"
    for c in "${FAILED_CASKS[@]}";    do printf '  %b\n' "${RED}✘${RESET}  cask: $c"; done
    for f in "${FAILED_FORMULAE[@]}"; do printf '  %b\n' "${RED}✘${RESET}  formula: $f"; done
    for p in "${FAILED_PIPS[@]}";     do printf '  %b\n' "${RED}✘${RESET}  pip: $p"; done
fi

echo ""
$DRY_RUN && info "Dry run complete — no changes were made." || success "Setup complete."
info "Log saved to $LOG_FILE"
