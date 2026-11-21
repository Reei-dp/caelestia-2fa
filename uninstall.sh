#!/usr/bin/env bash
set -e

echo "=== Uninstalling Caelestia 2FA Widget ==="

QS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
CAELESTIA_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia"
BIN_DIR="${XDG_DATA_HOME:-$HOME/.local}/bin"

# Remove QML module
rm -rf "$QS_CONFIG/modules/twofactor"

# Remove script & binary
rm -f "$CAELESTIA_CONFIG/scripts/2fa.py"
rm -f "$BIN_DIR/caelestia-2fa"

# Clean shell.qml
SHELL_QML="$QS_CONFIG/shell.qml"
if [ -f "$SHELL_QML" ]; then
    sed -i '/import "modules\/twofactor"/d' "$SHELL_QML"
    sed -i '/TwoFactor {}/d' "$SHELL_QML"
fi


# Restart shell
if command -v caelestia &>/dev/null; then
    killall qs 2>/dev/null || true
    sleep 0.5
    caelestia shell -d
fi

echo "✓ Uninstalled successfully. (Note: ~/.config/caelestia/2fa.json was preserved)"
