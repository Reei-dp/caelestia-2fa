#!/usr/bin/env bash
set -e

echo "=== Installing Caelestia 2FA Widget ==="

# Check dependencies
for cmd in python3 wl-copy; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed. Please install it first."
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
CAELESTIA_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia"
BIN_DIR="${XDG_DATA_HOME:-$HOME/.local}/bin"

# 1. Ensure user-level quickshell config exists
mkdir -p "$QS_CONFIG"
if [ ! -f "$QS_CONFIG/shell.qml" ] && [ -d "/etc/xdg/quickshell/caelestia" ]; then
    echo "Copying base Caelestia shell to user config..."
    cp -r /etc/xdg/quickshell/caelestia/* "$QS_CONFIG/"
fi

# 2. Copy TwoFactor module
echo "Installing QML module..."
mkdir -p "$QS_CONFIG/modules/twofactor"
cp "$SCRIPT_DIR/modules/twofactor/TwoFactor.qml" "$QS_CONFIG/modules/twofactor/"

# 3. Copy helper script and CLI
echo "Installing helper script..."
mkdir -p "$CAELESTIA_CONFIG/scripts" "$BIN_DIR"
cp "$SCRIPT_DIR/scripts/2fa.py" "$CAELESTIA_CONFIG/scripts/2fa.py"
chmod +x "$CAELESTIA_CONFIG/scripts/2fa.py"
ln -sf "$CAELESTIA_CONFIG/scripts/2fa.py" "$BIN_DIR/caelestia-2fa"

# 4. Inject TwoFactor into shell.qml if not present
SHELL_QML="$QS_CONFIG/shell.qml"
if [ -f "$SHELL_QML" ]; then
    if ! grep -q "modules/twofactor" "$SHELL_QML"; then
        echo "Registering module import in shell.qml..."
        sed -i '/import "modules\/lock"/a import "modules\/twofactor"' "$SHELL_QML"
    fi
    if ! grep -q "TwoFactor {" "$SHELL_QML"; then
        echo "Instantiating TwoFactor widget in shell.qml..."
        sed -i '/Lock {/ { :a; N; /}/!ba; a\    TwoFactor {}\n
        }' "$SHELL_QML"
    fi
fi

# 5. Enable click pass-through on desktop layer in Regions.qml
REGIONS_QML="$QS_CONFIG/modules/drawers/Regions.qml"
if [ -f "$REGIONS_QML" ] && ! grep -q "TwoFactor Pass-Through" "$REGIONS_QML"; then
    echo "Configuring click pass-through in Regions.qml..."
    sed -i '/component R: Region/i \    // TwoFactor Pass-Through\n    Region {\n        x: root.win.width - 380\n        y: 0\n        width: 380\n        height: 450\n        intersection: Intersection.Subtract\n    }\n' "$REGIONS_QML"
fi

# 6. Create default 2fa.json if missing
if [ ! -f "$CAELESTIA_CONFIG/2fa.json" ]; then
    cat <<EOF > "$CAELESTIA_CONFIG/2fa.json"
[
    {
        "name": "Demo Account",
        "secret": "JBSWY3DPEHPK3PXP"
    }
]
EOF
fi

# 6. Restart Caelestia shell
echo "Restarting Caelestia Shell..."
if command -v caelestia &>/dev/null; then
    killall qs 2>/dev/null || true
    sleep 0.5
    caelestia shell -d
    sleep 1
    caelestia shell toaster success "2FA Установлен" "Виджет успешно активирован в Caelestia" check 2>/dev/null || true
fi

echo "✓ Installation complete! Manage accounts with: caelestia-2fa add <Name> <Secret>"
