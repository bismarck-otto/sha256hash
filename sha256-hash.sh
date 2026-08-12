#!/usr/bin/env bash

# bismarck-otto 2026-08-12 to calculate hash with sha256-hash.sh

# Copyright (c) 2026 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Code snippets for file hash calculation
# ================================================================
#
# a) Create Desktop Entry for XFCE application definition 
# b) Create Desktop Entry for Thunar File Manager Send To definition
# c) Create XFCE Sign and Hash submenu definition
# d) Create Yellow Padlock SVG Icon

: <<'CONFIG_COMMENT'
# /usr/share/applications/sha256-hash.desktop

[Desktop Entry]
Version=1.0
Type=Application
Name=Calculate SHA256 Hash
Comment=Calculate a SHA256 hash and copy it to the clipboard
Exec=/opt/hash/sha256-hash.sh
Icon=sha256-hash-yellow-padlock
Terminal=false
StartupNotify=true
Categories=Utility;


# /usr/share/Thunar/sendto/sha256-hash.desktop

[Desktop Entry]
Version=1.0
Type=Application
Name=Calculate SHA256 Hash
Comment=Calculate SHA256 hash and copy it to the clipboard
TryExec=/opt/hash/sha256-hash.sh
Exec=/opt/hash/sha256-hash.sh %F
Icon=sha256-hash-yellow-padlock
Terminal=false
StartupNotify=true


# /etc/xdg/menus/applications-merged/sign-and-hash.menu

<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
"http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">

<Menu>
  <Name>Applications</Name>

  <Menu>
    <Name>SignAndHash</Name>

    <Directory>sign-and-hash.directory</Directory>

    <Include>
      <Filename>sha256-hash.desktop</Filename>
    </Include>

  </Menu>

</Menu>


# /usr/share/icons/hicolor/scalable/apps/sha256-hash-yellow-padlock.svg

sudo bash <<'EOF'
set -Eeuo pipefail

ICON_DIR="/usr/share/icons/hicolor/scalable/apps"
ICON_FILE="$ICON_DIR/sha256-hash-yellow-padlock.svg"

mkdir -p "$ICON_DIR"

cat > "$ICON_FILE" <<'SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="128"
     height="128"
     viewBox="0 0 128 128">

  <!-- Shackle -->
  <path
      d="M38 55 V39
         C38 24 49 13 64 13
         C79 13 90 24 90 39
         V55"
      fill="none"
      stroke="#8a6d00"
      stroke-width="11"
      stroke-linecap="round"/>

  <!-- Yellow lock body -->
  <rect
      x="24"
      y="50"
      width="80"
      height="65"
      rx="9"
      ry="9"
      fill="#ffd42a"
      stroke="#8a6d00"
      stroke-width="5"/>

  <!-- Highlight -->
  <path
      d="M32 61 H96"
      stroke="#fff3a3"
      stroke-width="5"
      stroke-linecap="round"
      opacity="0.8"/>

  <!-- Keyhole -->
  <circle
      cx="64"
      cy="78"
      r="9"
      fill="#5c4a00"/>

  <path
      d="M60 84 L57 101 H71 L68 84 Z"
      fill="#5c4a00"/>
</svg>
SVG

chown root:root "$ICON_FILE"
chmod 0644 "$ICON_FILE"

# Refresh icon cache
gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true

echo
echo "===== ICON CREATED ====="
echo "Icon name: sha256-hash-yellow-padlock"
echo "Icon file: $ICON_FILE"
EOF


# End of comment section with configuration info
CONFIG_COMMENT

# sha256-hash.sh
set -Eeuo pipefail

TITLE="SHA256 Hash"


# ------------------------------------------------------------
# GUI error dialog
# ------------------------------------------------------------

show_error() {
    zenity \
        --error \
        --title="$TITLE" \
        --width=520 \
        --text="$1" \
        2>/dev/null || true
}


# ------------------------------------------------------------
# Determine input file
#
# Two supported invocation methods:
#
# 1. XFCE application menu
#       /opt/hash/sha256-hash.sh
#
#    No argument:
#    Open GUI file chooser.
#
# 2. Thunar -> Send To -> Calculate SHA256 Hash
#
#       /opt/hash/sha256-hash.sh "/path/to/file"
#
#    Use file supplied by Thunar directly.
# ------------------------------------------------------------

if (( $# == 0 )); then

    FILE="$(
        zenity \
            --file-selection \
            --title="Select file to calculate SHA256 hash" \
            2>/dev/null
    )" || exit 0

    # Cancelled file chooser
    [[ -n "$FILE" ]] || exit 0

elif (( $# == 1 )); then

    FILE="$1"

else

    show_error "Calculate SHA256 Hash accepts one file at a time.

Please select one file in Thunar and use:

Send To → Calculate SHA256 Hash"

    exit 1
fi


# ------------------------------------------------------------
# Validate selected file
# ------------------------------------------------------------

if [[ ! -e "$FILE" ]]; then
    show_error "File not found:

$FILE"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    show_error "The selected item is not a regular file:

$FILE"
    exit 1
fi

if [[ ! -r "$FILE" ]]; then
    show_error "The selected file cannot be read:

$FILE"
    exit 1
fi


# ------------------------------------------------------------
# Calculate SHA256
# ------------------------------------------------------------

HASH="$(
    sha256sum -- "$FILE" |
        awk '{print $1}'
)"

HASH="${HASH,,}"


# ------------------------------------------------------------
# Validate calculated SHA256
# ------------------------------------------------------------

if [[ ! "$HASH" =~ ^[0-9a-f]{64}$ ]]; then
    show_error "Failed to calculate a valid SHA256 hash."
    exit 1
fi


FILE_NAME="$(basename -- "$FILE")"


# ------------------------------------------------------------
# Copy hash to X clipboard
#
# Keep the exact Windows clipboard format:
#
#     sha256:<64-character-lowercase-hash>
#
# No spaces.
# No newline.
# ------------------------------------------------------------

CLIPBOARD_TEXT="sha256:${HASH}"

if ! printf '%s' "$CLIPBOARD_TEXT" |
        xclip -selection clipboard
then
    show_error "The SHA256 hash was calculated, but it could not be copied to the clipboard."
    exit 1
fi


# ------------------------------------------------------------
# Format hash exactly according to the Windows logic:
#
# lowercase
# space after every byte pair
# split after 16 byte pairs
#
# Example:
#
# aa bb cc ... 16 pairs
# 11 22 33 ... 16 pairs
# ------------------------------------------------------------

HASH_FIRST="${HASH:0:32}"
HASH_SECOND="${HASH:32:32}"

format_pairs() {
    printf '%s' "$1" |
        sed -E \
            -e 's/(..)/\1 /g' \
            -e 's/[[:space:]]+$//'
}

LINE1="$(format_pairs "$HASH_FIRST")"
LINE2="$(format_pairs "$HASH_SECOND")"


# ------------------------------------------------------------
# Escape filename for Zenity/Pango markup
# ------------------------------------------------------------

ESCAPED_FILE_NAME="$(
    printf '%s' "$FILE_NAME" |
        sed \
            -e 's/&/\&amp;/g' \
            -e 's/</\&lt;/g' \
            -e 's/>/\&gt;/g'
)"


# ------------------------------------------------------------
# Display result
#
# Deliberately matches the Windows message:
#
# SHA256 hash of filename
#
# xx xx ...
# xx xx ...
#
# Clipboard operation has already happened before this dialog.
# ------------------------------------------------------------

MESSAGE="SHA256 hash of ${ESCAPED_FILE_NAME}

<span font_family=\"monospace\">${LINE1}
${LINE2}</span>"


zenity \
    --info \
    --title="$TITLE" \
    --width=650 \
    --text="$MESSAGE" \
    2>/dev/null || true

exit 0
