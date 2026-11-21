# caelestia-2fa

2FA TOTP authenticator widget designed for Caelestia Shell and Quickshell on Hyprland.

## Features
- Real-time 6-digit TOTP code generation
- Progress bar and 30-second countdown
- Click-to-copy via wl-copy with desktop notifications
- QR code batch import from Google Authenticator export
- Collapsible compact header mode
- Responsive Material Design 3 theming

## Dependencies
- Caelestia Shell & Quickshell
- python3
- wl-clipboard
- zbar (optional, for QR importing)

## Installation
Run `./install.sh` from the repository root.

## CLI Usage
- Add account: `caelestia-2fa add "Service" "SECRETKEY"`
- Import QR: `caelestia-2fa import-qr /path/to/qr.png`
- Remove: `caelestia-2fa rm "Service"`
- Copy code: `caelestia-2fa copy "Service"`
- List accounts: `caelestia-2fa list`
