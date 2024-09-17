#!/bin/bash

# Update macOS
softwareupdate --list
softwareupdate --install -a

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Install Xcode Command Line Tools
echo "Installing Xcode Command Line Tools..."
if ! xcode-select --print-path >/dev/null 2>&1; then
    xcode-select --install
else
    echo "Xcode Command Line Tools are already installed."
fi

# 2. Install Homebrew
if ! command_exists brew; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

# 3. Install specified packages
echo "Installing specified packages..."
brew install python@3.12 aria2 dos2unix gh libunistring pypy3.10 tcl-tk wget \
    ca-certificates gdbm libidn2 ncurses readline tree xz dmg2img \
    gettext libssh2 openssl@3 sqlite watch robot-framework

# 4. Install specified casks
echo "Installing specified casks..."
brew install --cask adobe-acrobat-reader gimp gstreamer-development \
    gstreamer-runtime podman-desktop utm microsoft-azure-storage-explorer \
    visual-studio-code coteditor pycharm-ce chatgpt pgadmin4 \
    omnidisksweeper disk-drill audacity logi-options+ vlc

echo "All specified packages and casks have been installed!"
