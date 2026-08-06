#!/bin/sh
set -eu
REPO="theorzr/portablemc"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/portablemc"
BIN="$INSTALL_DIR/portablemc"
# formatted console output
info() {
    printf '\033[1;36m[Devcraft]\033[0m %s\n' "$1"
}
err() {
    printf '\033[1;31m[Devcraft Error]\033[0m %s\n' "$1" >&2
}
# download and setup PortableMC if not already installed
if ! command -v portablemc >/dev/null 2>&1 && [ ! -x "$BIN" ]; then
    info "PortableMC not found locally. Preparing download..."
    # detect Operating System
    OS="$(uname -s)"
    case "$OS" in
        Linux*)  OS_TARGET="linux" ;;
        Darwin*) OS_TARGET="macos" ;;
        *)
            err "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    # detect Architecture
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)
            if [ "$OS_TARGET" = "linux" ]; then
                ARCH_TARGET="x86_64-gnu"
            else
                ARCH_TARGET="x86_64"
            fi
            ;;
        aarch64|arm64)
            if [ "$OS_TARGET" = "linux" ]; then
                ARCH_TARGET="aarch64-gnu"
            else
                ARCH_TARGET="aarch64"
            fi
            ;;
        armv6*|armv7*|armhf)
            if [ "$OS_TARGET" = "linux" ]; then
                ARCH_TARGET="arm-gnueabihf"
            else
                err "Unsupported architecture for $OS: $ARCH"
                exit 1
            fi
            ;;
        i386|i686)
            if [ "$OS_TARGET" = "linux" ]; then
                ARCH_TARGET="i686-gnu"
            else
                err "Unsupported architecture for $OS: $ARCH"
                exit 1
            fi
            ;;
        *)
            err "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    # helper function to download files
    download_file() {
        _url="$1"
        _output="$2"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$_url" -o "$_output"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$_output" "$_url"
        else
            err "Neither 'curl' nor 'wget' is installed. Please install one to continue."
            exit 1
        fi
    }
    # resolve latest release tag from GitHub
    LATEST_URL="https://github.com/$REPO/releases/latest"
    EFFECTIVE_URL=""
    if command -v curl >/dev/null 2>&1; then
        EFFECTIVE_URL="$(curl -sSLI -o /dev/null -w "%{url_effective}" "$LATEST_URL" 2>/dev/null || true)"
    elif command -v wget >/dev/null 2>&1; then
        EFFECTIVE_URL="$(wget --spider -S "$LATEST_URL" 2>&1 | awk '/^  Location: /{print $2}' | tail -n 1 || true)"
    fi
    TAG="${EFFECTIVE_URL##*/}"
    # fallback to GitHub API if tag could not be obtained via redirect
    if [ -z "$TAG" ] || [ "$TAG" = "latest" ]; then
        API_URL="https://api.github.com/repos/$REPO/releases/latest"
        if command -v curl >/dev/null 2>&1; then
            TAG="$(curl -fsSL "$API_URL" 2>/dev/null | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)"
        elif command -v wget >/dev/null 2>&1; then
            TAG="$(wget -qO- "$API_URL" 2>/dev/null | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)"
        fi
    fi
    if [ -z "$TAG" ]; then
        err "Failed to determine latest PortableMC version. Please check your internet connection."
        exit 1
    fi
    VERSION="${TAG#v}"
    ASSET_NAME="portablemc-${VERSION}-${OS_TARGET}-${ARCH_TARGET}.tar.gz"
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/${TAG}/${ASSET_NAME}"
    info "Downloading PortableMC ($TAG for $OS_TARGET-$ARCH_TARGET)..."

    TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'portablemc')"
    ARCHIVE_PATH="$TMP_DIR/$ASSET_NAME"
    cleanup() {
        rm -rf "$TMP_DIR"
    }
    trap cleanup EXIT INT TERM

    download_file "$DOWNLOAD_URL" "$ARCHIVE_PATH"

    info "Extracting..."
    tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"
    EXTRACTED_BIN="$(find "$TMP_DIR" -type f -name "portablemc" | head -n 1)"
    if [ -z "$EXTRACTED_BIN" ] || [ ! -f "$EXTRACTED_BIN" ]; then
        err "Could not find 'portablemc' binary in the downloaded archive."
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"
    mv "$EXTRACTED_BIN" "$BIN"
    chmod +x "$BIN"
    info "PortableMC successfully installed to $BIN"
fi
# locate the binary to execute
if [ -x "$BIN" ]; then
    PORTABLEMC_EXEC="$BIN"
elif command -v portablemc >/dev/null 2>&1; then
    PORTABLEMC_EXEC="$(command -v portablemc)"
else
    err "PortableMC executable not found."
    exit 1
fi
# launch PortableMC with provided arguments, or launch game if none specified
if [ $# -eq 0 ]; then
    info "Launching Minecraft via PortableMC..."
    exec "$PORTABLEMC_EXEC" start
else
    exec "$PORTABLEMC_EXEC" "$@"
fi
