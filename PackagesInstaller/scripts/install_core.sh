#!/usr/bin/env bash
# BrewInstaller core script — called by the macOS GUI app
# All output lines are prefixed with a tag the Swift app parses:
#   INFO:   informational message
#   OK:     success
#   WARN:   warning
#   ERROR:  error
#   PROGRESS:<step>:<total>:<label>   progress update
#   DONE:   installation complete

set -uo pipefail

PACKAGES_JSON="${1:-$(dirname "$0")/../packages.json}"

log_info()     { printf 'INFO: %s\n'     "$*"; }
log_ok()       { printf 'OK: %s\n'       "$*"; }
log_warn()     { printf 'WARN: %s\n'     "$*"; }
log_error()    { printf 'ERROR: %s\n'    "$*"; }
log_progress() { printf 'PROGRESS:%s:%s:%s\n' "$1" "$2" "$3"; }

# ── Require jq ────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    log_error "jq is required but not installed. Installing via Homebrew first..."
    brew install jq --quiet || { log_error "Failed to install jq. Aborting."; exit 1; }
fi

# ── Parse packages.json ───────────────────────────────────
CASKS=$(jq -r '.casks[].id'        "$PACKAGES_JSON" 2>/dev/null)
FORMULAE=$(jq -r '.formulae[].id'  "$PACKAGES_JSON" 2>/dev/null)
PIP_PKGS=$(jq -r '.pip_packages[].id' "$PACKAGES_JSON" 2>/dev/null)

ENABLE_TOUCHID=$(jq -r '.settings.enable_touchid_sudo'                 "$PACKAGES_JSON" 2>/dev/null)
CONF_PIP=$(jq -r       '.settings.configure_pip_break_system_packages' "$PACKAGES_JSON" 2>/dev/null)
INSTALL_PW=$(jq -r     '.settings.install_playwright_browsers'         "$PACKAGES_JSON" 2>/dev/null)

CASK_ARR=(); while IFS= read -r line; do [[ -n "$line" ]] && CASK_ARR+=("$line"); done <<< "$CASKS"
FORM_ARR=(); while IFS= read -r line; do [[ -n "$line" ]] && FORM_ARR+=("$line"); done <<< "$FORMULAE"
PIP_ARR=();  while IFS= read -r line; do [[ -n "$line" ]] && PIP_ARR+=("$line");  done <<< "$PIP_PKGS"

TOTAL_STEPS=$(( ${#CASK_ARR[@]} + ${#FORM_ARR[@]} ))
CURRENT_STEP=0

# ── macOS only ────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is for macOS only."
    exit 1
fi

# ─────────────────────────────────────────────────────────
# 1. TOUCHID FOR SUDO
# ─────────────────────────────────────────────────────────
if [[ "$ENABLE_TOUCHID" == "true" ]]; then
    log_info "Configuring TouchID for sudo..."
    PAM_SUDO="/etc/pam.d/sudo"
    TOUCHID_LINE="auth       sufficient     pam_tid.so"

    if grep -q "pam_tid.so" "$PAM_SUDO" 2>/dev/null; then
        log_ok "TouchID for sudo already enabled in $PAM_SUDO."
    else
        PAM_SUDO_LOCAL="/etc/pam.d/sudo_local"
        if [[ -f "$PAM_SUDO_LOCAL" ]]; then
            if grep -q "pam_tid.so" "$PAM_SUDO_LOCAL" 2>/dev/null; then
                log_ok "TouchID for sudo already enabled in sudo_local."
            else
                echo "$TOUCHID_LINE" | sudo tee -a "$PAM_SUDO_LOCAL" > /dev/null \
                    && log_ok "TouchID enabled in $PAM_SUDO_LOCAL." \
                    || log_warn "Could not write to $PAM_SUDO_LOCAL — run with sudo."
            fi
        elif [[ -f "${PAM_SUDO_LOCAL}.template" ]]; then
            sudo cp "${PAM_SUDO_LOCAL}.template" "$PAM_SUDO_LOCAL"
            sudo sed -i '' "s/#auth/auth/" "$PAM_SUDO_LOCAL"
            log_ok "TouchID enabled via sudo_local template."
        else
            sudo sed -i '' "1a\\
$TOUCHID_LINE
" "$PAM_SUDO" 2>/dev/null \
                && log_ok "TouchID patched into $PAM_SUDO." \
                || log_warn "Could not patch $PAM_SUDO — add manually: $TOUCHID_LINE"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────
# 2. HOMEBREW
# ─────────────────────────────────────────────────────────
log_info "Checking Homebrew..."

if command -v brew &>/dev/null; then
    log_ok "Homebrew already installed at $(brew --prefix)."
    log_info "Updating Homebrew..."
    brew update --quiet && log_ok "Homebrew updated."
else
    log_info "Installing Homebrew (this may take a few minutes)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        && log_ok "Homebrew installed." \
        || { log_error "Homebrew installation failed."; exit 1; }

    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        PROFILE="$HOME/.zprofile"
        if ! grep -q "homebrew/bin/brew shellenv" "$PROFILE" 2>/dev/null; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$PROFILE"
            log_info "Added brew to $PROFILE."
        fi
    fi
fi

# ─────────────────────────────────────────────────────────
# 3. CASKS
# ─────────────────────────────────────────────────────────
log_info "Installing ${#CASK_ARR[@]} cask(s)..."

for cask in "${CASK_ARR[@]}"; do
    log_progress "$CURRENT_STEP" "$TOTAL_STEPS" "$cask"
    if brew list --cask "$cask" &>/dev/null; then
        log_ok "$cask already installed — skipping."
    else
        log_info "Installing $cask..."
        if brew install --cask "$cask" 2>&1 | while IFS= read -r line; do log_info "  $line"; done; then
            log_ok "$cask installed."
        else
            log_warn "$cask installation failed or was skipped."
        fi
    fi
    (( CURRENT_STEP++ )) || true
done

# ─────────────────────────────────────────────────────────
# 4. FORMULAE
# ─────────────────────────────────────────────────────────
log_info "Installing ${#FORM_ARR[@]} formula(e)..."

for formula in "${FORM_ARR[@]}"; do
    log_progress "$CURRENT_STEP" "$TOTAL_STEPS" "$formula"
    if brew list "$formula" &>/dev/null; then
        log_ok "$formula already installed — skipping."
    else
        log_info "Installing $formula..."
        if brew install "$formula" 2>&1 | while IFS= read -r line; do log_info "  $line"; done; then
            log_ok "$formula installed."
        else
            log_warn "$formula installation failed."
        fi
    fi
    (( CURRENT_STEP++ )) || true
done

log_progress "$TOTAL_STEPS" "$TOTAL_STEPS" "All packages processed"

# ─────────────────────────────────────────────────────────
# 5. PIP
# ─────────────────────────────────────────────────────────
if [[ ${#PIP_ARR[@]} -gt 0 ]]; then
    log_info "Configuring pip..."

    PYTHON_BIN="$(brew --prefix)/bin/python3"
    PIP_BIN="$(brew --prefix)/bin/pip3"

    if [[ "$CONF_PIP" == "true" ]]; then
        PIP_CONF_DIR="$HOME/Library/Application Support/pip"
        PIP_CONF_FILE="$PIP_CONF_DIR/pip.conf"
        mkdir -p "$PIP_CONF_DIR"
        if grep -q "break-system-packages" "$PIP_CONF_FILE" 2>/dev/null; then
            log_ok "pip.conf already configured."
        else
            printf '[global]\nbreak-system-packages = true\n' >> "$PIP_CONF_FILE"
            log_ok "pip.conf updated — pip will not require venv."
        fi
    fi

    "$PYTHON_BIN" -m pip install --upgrade pip --break-system-packages --quiet \
        && log_ok "pip upgraded." \
        || log_warn "pip upgrade failed — continuing."

    for pkg in "${PIP_ARR[@]}"; do
        if "$PIP_BIN" show "$pkg" &>/dev/null; then
            log_ok "$pkg already installed — skipping."
        else
            log_info "Installing pip package: $pkg..."
            if "$PIP_BIN" install "$pkg" --break-system-packages --quiet; then
                log_ok "$pkg installed."
            else
                log_warn "$pkg installation failed."
            fi
        fi
    done

    if [[ "$INSTALL_PW" == "true" ]] && "$PYTHON_BIN" -m playwright --version &>/dev/null 2>&1; then
        log_info "Installing Playwright browsers..."
        "$PYTHON_BIN" -m playwright install \
            && log_ok "Playwright browsers installed." \
            || log_warn "Playwright browser install failed. Run: python3 -m playwright install"
    fi
fi

# ─────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────
printf 'DONE:\n'
