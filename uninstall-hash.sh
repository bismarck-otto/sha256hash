#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF_NAME="$(basename -- "$0")"

CONFIG_MARKER=": <<'CONFIG_COMMENT'"
SVG_TARGET="/usr/share/icons/hicolor/scalable/apps/sha256-hash-yellow-padlock.svg"
MENU_TARGET="/etc/xdg/menus/applications-merged/sign-and-hash.menu"

removed_count=0
updated_count=0
skipped_count=0
svg_removed=0

declare -a HASH_MENU_ENTRIES=()

echo "===== UNINSTALL HASH DEFINITIONS ====="
echo "Source directory: $SCRIPT_DIR"
echo

is_valid_hash_script() {
    local file="$1"
    local first_line

    IFS= read -r first_line < "$file" || return 1

    case "$first_line" in
        '#!/usr/bin/env bash'|'#!/bin/bash') ;;
        *) return 1 ;;
    esac

    grep -Fqx "$CONFIG_MARKER" "$file"
}

extract_config_comment() {
    local file="$1"

    awk '
        $0 == ": <<'\''CONFIG_COMMENT'\''" {
            in_block = 1
            next
        }
        in_block && $0 == "CONFIG_COMMENT" {
            exit
        }
        in_block {
            print
        }
    ' "$file"
}

extract_declared_block() {
    local config_file="$1"
    local target="$2"

    awk -v target="$target" '
        $0 == "# " target {
            capture = 1
            next
        }
        capture && /^# \// {
            exit
        }
        capture {
            print
        }
    ' "$config_file"
}

remove_target() {
    local target="$1"

    if [[ -e "$target" || -L "$target" ]]; then
        rm -f -- "$target"
        echo "[REMOVE] $target"
        ((removed_count += 1))
    else
        echo "[ABSENT] $target"
    fi
}

register_hash_menu_entry() {
    local config_file="$1"
    local desktop
    local existing

    desktop="$(
        extract_declared_block "$config_file" "$MENU_TARGET" |
        sed -n 's@^[[:space:]]*<Filename>\([^<]*\)</Filename>[[:space:]]*$@\1@p' |
        head -n1
    )"

    [[ -n "$desktop" ]] || return 1

    case "$desktop" in
        *-hash.desktop) ;;
        *) return 1 ;;
    esac

    for existing in "${HASH_MENU_ENTRIES[@]:-}"; do
        [[ "$existing" == "$desktop" ]] && return 0
    done

    HASH_MENU_ENTRIES+=("$desktop")
}

remove_svg_once() {
    (( svg_removed )) && return 0

    remove_target "$SVG_TARGET"
    svg_removed=1
}

update_shared_menu_preserving_other_apps() {
    [[ -f "$MENU_TARGET" ]] || {
        echo "[ABSENT] $MENU_TARGET"
        return 0
    }

    local tmp desktop remaining
    tmp="$(mktemp)"
    cp -a "$MENU_TARGET" "$tmp"

    # Remove only hash applications represented by qualifying sibling scripts.
    # Every unrelated application entry remains untouched.
    for desktop in "${HASH_MENU_ENTRIES[@]}"; do
        awk -v name="$desktop" '
            {
                line = $0
                test = line
                sub(/^[[:space:]]*/, "", test)
                sub(/[[:space:]]*$/, "", test)

                if (test == "<Filename>" name "</Filename>") {
                    next
                }

                print
            }
        ' "$tmp" > "${tmp}.new"
        mv "${tmp}.new" "$tmp"
    done

    remaining="$(
        sed -n 's@^[[:space:]]*<Filename>\([^<]*\)</Filename>[[:space:]]*$@\1@p' "$tmp" |
        wc -l
    )"

    if (( remaining > 0 )); then
        cp "$tmp" "$MENU_TARGET"
        chown root:root "$MENU_TARGET"
        chmod 0644 "$MENU_TARGET"

        echo "[UPDATE] $MENU_TARGET"
        echo "         Preserved $remaining remaining application entr$( (( remaining == 1 )) && printf 'y' || printf 'ies')."
        ((updated_count += 1))
    else
        rm -f -- "$MENU_TARGET"
        echo "[REMOVE] $MENU_TARGET"
        echo "         No application entries remain in Sign and Hash."
        ((removed_count += 1))
    fi

    rm -f "$tmp"
}

shopt -s nullglob

for file in "$SCRIPT_DIR"/*-hash.sh; do
    base="$(basename -- "$file")"

    case "$base" in
        "$SELF_NAME"|install-hash.sh|uninstall-hash.sh)
            continue
            ;;
    esac

    if ! is_valid_hash_script "$file"; then
        echo "[SKIP] $base — not a qualifying Bash hash script."
        ((skipped_count += 1))
        continue
    fi

    echo "[READ] $base"

    tmp="$(mktemp)"
    extract_config_comment "$file" > "$tmp"

    mapfile -t targets < <(
        sed -n 's/^# \(\/.*\)$/\1/p' "$tmp"
    )

    for target in "${targets[@]}"; do
        case "$target" in
            "$SVG_TARGET")
                # Shared SVG is removed once after all scripts are scanned.
                ;;
            "$MENU_TARGET")
                register_hash_menu_entry "$tmp" || true
                ;;
            *.desktop)
                remove_target "$target"
                ;;
            *.directory)
                # Directory definitions may be shared by non-hash apps.
                # Do not remove them here.
                echo "[KEEP] Shared directory definition: $target"
                ;;
            *.menu)
                remove_target "$target"
                ;;
            *)
                echo "[SKIP] Unsupported declared target: $target"
                ;;
        esac
    done

    rm -f "$tmp"
    echo
done

# Shared menu is modified exactly once. It is retained whenever any
# unrelated application entry remains.
update_shared_menu_preserving_other_apps

# Shared yellow padlock SVG is removed exactly once per execution.
remove_svg_once

update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true

echo
echo "===== UNINSTALL COMPLETE ====="
echo "Removed:        $removed_count"
echo "Updated:        $updated_count"
echo "Skipped inputs: $skipped_count"
