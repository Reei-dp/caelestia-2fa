#!/usr/bin/env python3
"""
Caelestia 2FA Helper Script & CLI
Handles TOTP generation, clipboard integration, and Google Authenticator QR migration.
"""

import sys
import os
import json
import time
import base64
import hmac
import hashlib
import struct
import subprocess
import urllib.parse

CONFIG_PATH = os.path.expanduser("~/.config/caelestia/2fa.json")

def get_totp(secret):
    try:
        clean_sec = secret.strip().replace(" ", "").replace("-", "").upper()
        padding = len(clean_sec) % 8
        if padding:
            clean_sec += "=" * (8 - padding)
        key = base64.b32decode(clean_sec, casefold=True)
        counter = int(time.time() // 30)
        msg = struct.pack(">Q", counter)
        h = hmac.new(key, msg, hashlib.sha1).digest()
        offset = h[-1] & 0x0F
        code_int = (struct.unpack(">I", h[offset:offset+4])[0] & 0x7FFFFFFF) % 1000000
        raw = f"{code_int:06d}"
        formatted = f"{raw[:3]} {raw[3:]}"
        return raw, formatted
    except Exception as e:
        return "ERROR", "ERR ERR"

def load_accounts():
    if not os.path.exists(CONFIG_PATH):
        return []
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []

def save_accounts(accounts):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(accounts, f, indent=4, ensure_ascii=False)

def cmd_get():
    accounts = load_accounts()
    now = time.time()
    remaining = 30 - int(now) % 30
    progress = remaining / 30.0

    res = []
    for acc in accounts:
        name = acc.get("name", "Account")
        secret = acc.get("secret", "")
        raw, formatted = get_totp(secret)
        res.append({
            "name": name,
            "raw": raw,
            "code": formatted
        })

    out = {
        "remaining": remaining,
        "progress": round(progress, 3),
        "accounts": res
    }
    print(json.dumps(out, ensure_ascii=False))

def cmd_copy(target_name):
    accounts = load_accounts()
    for acc in accounts:
        if acc.get("name", "").lower() == target_name.lower():
            raw, _ = get_totp(acc.get("secret", ""))
            try:
                subprocess.run(["wl-copy", raw], check=True)
                subprocess.run([
                    "caelestia", "shell", "toaster", "success",
                    "2FA Код скопирован",
                    f"{acc.get('name')} скопирован в буфер",
                    "check"
                ], stderr=subprocess.DEVNULL)
            except Exception as e:
                print(f"Error copying: {e}", file=sys.stderr)
            return
    print(f"Account '{target_name}' not found", file=sys.stderr)

def cmd_add(name, secret):
    accounts = load_accounts()
    for acc in accounts:
        if acc.get("name") == name:
            acc["secret"] = secret
            save_accounts(accounts)
            print(f"✓ Updated account '{name}'")
            return
    accounts.append({"name": name, "secret": secret})
    save_accounts(accounts)
    print(f"✓ Added account '{name}'")

def cmd_remove(name):
    accounts = load_accounts()
    filtered = [acc for acc in accounts if acc.get("name", "").lower() != name.lower()]
    if len(filtered) != len(accounts):
        save_accounts(filtered)
        print(f"✓ Removed account '{name}'")
    else:
        print(f"Account '{name}' not found")

def parse_protobuf(data):
    i = 0
    items = []
    while i < len(data):
        tag_byte = data[i]
        i += 1
        field_num = tag_byte >> 3
        wire_type = tag_byte & 7

        if wire_type == 0:  # varint
            val = 0
            shift = 0
            while True:
                b = data[i]
                i += 1
                val |= (b & 0x7F) << shift
                if not (b & 0x80):
                    break
                shift += 7
            items.append((field_num, val))
        elif wire_type == 2:  # length-delimited
            length = 0
            shift = 0
            while True:
                b = data[i]
                i += 1
                length |= (b & 0x7F) << shift
                if not (b & 0x80):
                    break
                shift += 7
            payload = data[i:i + length]
            i += length
            items.append((field_num, payload))
        else:
            break
    return items

def cmd_import_qr(image_path):
    if not os.path.exists(image_path):
        print(f"Error: file '{image_path}' not found", file=sys.stderr)
        return

    try:
        proc = subprocess.run(["zbarimg", "--raw", image_path], capture_output=True, text=True, check=True)
        raw_output = proc.stdout.strip()
    except FileNotFoundError:
        print("Error: 'zbarimg' is not installed. Run 'sudo pacman -S zbar' to install it.", file=sys.stderr)
        return
    except subprocess.CalledProcessError:
        print(f"Error: could not read QR code from '{image_path}'", file=sys.stderr)
        return

    for line in raw_output.splitlines():
        line = line.strip()
        if line.startswith("otpauth-migration://offline?data="):
            parsed = urllib.parse.urlparse(line)
            qs = urllib.parse.parse_qs(parsed.query)
            data = base64.b64decode(qs["data"][0])
            root_fields = parse_protobuf(data)

            imported = 0
            for field_num, payload in root_fields:
                if field_num == 1:
                    otp_fields = parse_protobuf(payload)
                    otp = {}
                    for fn, val in otp_fields:
                        if fn == 1:
                            otp["secret"] = base64.b32encode(val).decode("ascii")
                        elif fn == 2:
                            otp["name"] = val.decode("utf-8", errors="replace")
                        elif fn == 3:
                            otp["issuer"] = val.decode("utf-8", errors="replace")

                    if "secret" in otp and "name" in otp:
                        title = otp["name"]
                        if otp.get("issuer") and otp["issuer"].lower() not in title.lower():
                            title = f"{otp['issuer']} ({title})"
                        cmd_add(title, otp["secret"])
                        imported += 1
            print(f"✓ Successfully imported {imported} account(s) from QR code.")
            return
        elif line.startswith("otpauth://totp/"):
            parsed = urllib.parse.urlparse(line)
            qs = urllib.parse.parse_qs(parsed.query)
            name = urllib.parse.unquote(parsed.path.lstrip("/"))
            secret = qs.get("secret", [""])[0]
            if secret:
                cmd_add(name, secret)
                print(f"✓ Imported '{name}' from standard otpauth URI.")
                return

    print("Error: QR code did not contain a recognized otpauth or Google Authenticator migration URI.", file=sys.stderr)

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "get":
        cmd_get()
    elif sys.argv[1] == "copy" and len(sys.argv) > 2:
        cmd_copy(sys.argv[2])
    elif sys.argv[1] == "add" and len(sys.argv) > 3:
        cmd_add(sys.argv[2], sys.argv[3])
    elif sys.argv[1] in ("rm", "remove", "delete") and len(sys.argv) > 2:
        cmd_remove(sys.argv[2])
    elif sys.argv[1] in ("import", "import-qr") and len(sys.argv) > 2:
        cmd_import_qr(sys.argv[2])
    elif sys.argv[1] == "list":
        for acc in load_accounts():
            print(f"- {acc.get('name')}")
    else:
        print("Usage: caelestia-2fa [get | copy <name> | add <name> <secret> | rm <name> | import-qr <image> | list]")

if __name__ == "__main__":
    main()
