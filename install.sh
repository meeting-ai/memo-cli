#!/bin/bash
set -euo pipefail

# memo installer
#
# Downloads the latest memo release for this machine from
# https://github.com/meeting-ai/memo-cli, verifies its SHA-256 checksum,
# installs the binary to ~/.local/bin/memo, and installs the agent skill
# file for any AI agents detected on the machine.
#
# One line:
#   curl -fsSL https://raw.githubusercontent.com/meeting-ai/memo-cli/main/install.sh | bash
#
# Options (environment variables):
#   MEMO_VERSION       install a specific tag, e.g. v0.13.0 (default: latest)
#   MEMO_INSTALL_DIR   where to put the binary (default: ~/.local/bin)
#   GITHUB_TOKEN       only needed while the repository is private

REPO="meeting-ai/memo-cli"
BINARY_NAME="memo"
INSTALL_DIR="${MEMO_INSTALL_DIR:-$HOME/.local/bin}"
API="https://api.github.com/repos/${REPO}"

say()  { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v tar  >/dev/null 2>&1 || fail "tar is required."

# --- Detect platform ---

case "$(uname -s)" in
    Darwin) OS_TAG="darwin" ;;
    Linux)  OS_TAG="linux" ;;
    *)      fail "Unsupported operating system: $(uname -s). memo ships for macOS and Linux." ;;
esac

case "$(uname -m)" in
    arm64 | aarch64) ARCH_TAG="arm64" ;;
    x86_64 | amd64)  ARCH_TAG="amd64" ;;
    *)               fail "Unsupported architecture: $(uname -m). memo ships for amd64 and arm64." ;;
esac

say "Detected platform: ${OS_TAG}/${ARCH_TAG}"

# --- Resolve the release ---

AUTH_ARGS=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_ARGS=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [ -n "${MEMO_VERSION:-}" ]; then
    RELEASE_URL="${API}/releases/tags/${MEMO_VERSION}"
else
    RELEASE_URL="${API}/releases/latest"
fi

RELEASE_JSON="$(curl -fsSL "${AUTH_ARGS[@]}" -H "Accept: application/vnd.github+json" "$RELEASE_URL" 2>/dev/null)" \
    || fail "Could not find a memo release at ${RELEASE_URL}. Check https://github.com/${REPO}/releases."

VERSION="$(printf '%s' "$RELEASE_JSON" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$VERSION" ] || fail "Could not read the release tag from GitHub."
say "Installing memo ${VERSION}"

# Pick the asset for this platform and the checksums file. Archives are named
# memo_<version>_<os>_<arch>.tar.gz by the release pipeline.
ARCHIVE_NAME="$(printf '%s' "$RELEASE_JSON" | sed -n 's/.*"name": *"\(memo_[^"]*'"${OS_TAG}_${ARCH_TAG}"'\.tar\.gz\)".*/\1/p' | head -1)"
[ -n "$ARCHIVE_NAME" ] || fail "Release ${VERSION} has no archive for ${OS_TAG}/${ARCH_TAG}."

asset_url() {
    # Prints a download URL for the named asset. Public repos use the browser
    # URL; with a token we go through the asset API so auth survives the redirect.
    local name="$1"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        local id
        id="$(printf '%s' "$RELEASE_JSON" | tr -d '\n' | sed -n 's/.*"url": *"[^"]*\/releases\/assets\/\([0-9]*\)",[^}]*"name": *"'"${name}"'".*/\1/p' | head -1)"
        [ -n "$id" ] || fail "Could not resolve the asset id for ${name}."
        printf '%s/releases/assets/%s' "$API" "$id"
    else
        printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$VERSION" "$name"
    fi
}

download() {
    local name="$1" dest="$2"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL "${AUTH_ARGS[@]}" -H "Accept: application/octet-stream" "$(asset_url "$name")" -o "$dest"
    else
        curl -fsSL "$(asset_url "$name")" -o "$dest"
    fi
}

# --- Download and verify ---

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

say "Downloading ${ARCHIVE_NAME}..."
download "$ARCHIVE_NAME" "${TMPDIR}/${ARCHIVE_NAME}"

if download "checksums.txt" "${TMPDIR}/checksums.txt" 2>/dev/null; then
    EXPECTED="$(grep " ${ARCHIVE_NAME}\$" "${TMPDIR}/checksums.txt" | awk '{print $1}')"
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL="$(sha256sum "${TMPDIR}/${ARCHIVE_NAME}" | awk '{print $1}')"
    else
        ACTUAL="$(shasum -a 256 "${TMPDIR}/${ARCHIVE_NAME}" | awk '{print $1}')"
    fi
    [ -n "$EXPECTED" ] || fail "checksums.txt has no entry for ${ARCHIVE_NAME}."
    [ "$EXPECTED" = "$ACTUAL" ] || fail "Checksum mismatch for ${ARCHIVE_NAME}. Refusing to install."
    say "Checksum verified."
else
    say "Warning: checksums.txt not found in this release; skipping verification." >&2
fi

# --- Install ---

tar -xzf "${TMPDIR}/${ARCHIVE_NAME}" -C "$TMPDIR" "$BINARY_NAME"
mkdir -p "$INSTALL_DIR"
install -m 0755 "${TMPDIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
say "Installed ${BINARY_NAME} to ${INSTALL_DIR}/${BINARY_NAME}"

# --- Make sure the install dir is on PATH ---

MEMO_PATH_MARKER="# Added by memo installer"

append_path_to_rc() {
    local shell_name rc_file export_line
    shell_name="$(basename "${SHELL:-}")"
    case "$shell_name" in
        bash) rc_file="$HOME/.bashrc";  export_line="export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
        zsh)  rc_file="$HOME/.zshrc";   export_line="export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
        fish) rc_file="$HOME/.config/fish/config.fish"; export_line="set -gx PATH ${INSTALL_DIR} \$PATH" ;;
        *)
            say "" >&2
            say "Warning: ${INSTALL_DIR} is not on your PATH, and your shell (${SHELL:-unknown}) is not auto-configured." >&2
            say "Add this line to your shell profile:  export PATH=\"${INSTALL_DIR}:\$PATH\"" >&2
            return 0 ;;
    esac
    mkdir -p "$(dirname "$rc_file")"
    if [ -f "$rc_file" ] && grep -F "$MEMO_PATH_MARKER" "$rc_file" >/dev/null 2>&1; then
        say "${INSTALL_DIR} is already configured in ${rc_file}."
        return 0
    fi
    touch "$rc_file"
    printf '\n%s\n%s\n' "$MEMO_PATH_MARKER" "$export_line" >> "$rc_file"
    say "Added ${INSTALL_DIR} to PATH in ${rc_file}. Restart your shell or run: source ${rc_file}"
}

case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *) append_path_to_rc ;;
esac

# --- Verify and install the agent skill ---

MEMO_BIN="${INSTALL_DIR}/${BINARY_NAME}"
say "Installed version: $("$MEMO_BIN" version --jq .data.version 2>/dev/null | tr -d '"' || echo unknown)"

say "Installing the agent skill file..."
"$MEMO_BIN" install-skill-md --silent >/dev/null 2>&1 || true

say ""
say "memo ${VERSION} is installed. Next: memo auth login"
