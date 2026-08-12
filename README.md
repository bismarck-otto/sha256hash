# Calculate Hash Project

## Scripts

- `install-hash.sh` — Installs the available hash tools into XFCE and Thunar.
- `uninstall-hash.sh` — Removes the installed hash-tool definitions while preserving unrelated applications.
- `md5-hash.sh` — Calculates an MD5 hash.
- `sha1-hash.sh` — Calculates a SHA-1 hash.
- `sha256-hash.sh` — Calculates a SHA-256 hash.
- `sha512-hash.sh` — Calculates a SHA-512 hash.

- `MD5-Hash.ps1` — Calculates an MD5 hash on Windows.
- `SHA2-Hash.ps1` — Calculates an SHA-1 hash on Windows.
- `SHA256-Hash.ps1` — Calculates an SHA-256 hash on Windows.
- `SHA512-Hash.ps1` — Calculates an SHA-512 hash on Windows.

## Installation

Place `install-hash.sh`, `uninstall-hash.sh`, and the desired `*-hash.sh`
scripts in:

    /opt/hash

Run `install-hash.sh` to install the available hash tools. The applications
provide graphical hash calculation, clipboard output, and Thunar "Send To"
integration.

Run `uninstall-hash.sh` to remove the hash-tool integration.

On Windows, place the desired `*-Hash.ps1` scripts in:

    C:\Path\To\

The applications provide graphical hash calculation, clipboard output,
and Windows "Send To" integration.

Create a shortcut in the SendTo folder:

a) Press Win + R, type `shell:sendto`, press Enter.  
b) Right-click in the folder → New > Shortcut.  
c) Point it to/Type the location to the item:

    powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\MD5-Hash.ps1"

d) Replace `C:\Path\To\` with the actual path to your `MD5-Hash.ps1` file.  
e) Name it something like `MD5 Hash`.  
f) Right-click on the new shortcut → Properties > Run: `Minimized`.

## License and Development

Copyright (c) 2025-2026 Otto von Bismarck

This project includes portions generated using OpenAI's ChatGPT.

All code is released under the MIT License. See `LICENSE` for the complete
license terms.
