#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF_NAME="$(basename -- "$0")"

CONFIG_MARKER=": <<'CONFIG_COMMENT'"
SVG_TARGET="/usr/share/icons/hicolor/scalable/apps/sha256-hash-yellow-padlock.svg"
MENU_TARGET="/etc/xdg/menus/applications-merged/sign-and-hash.menu"

created_count=0
updated_count=0
skipped_count=0
svg_created=0

declare -a HASH_MENU_ENTRIES=()

echo "===== INSTALL HASH DEFINITIONS ====="
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
    ' "$config_file" |
    awk '
        {
            lines[NR] = $0
            if ($0 !~ /^[[:space:]]*$/) {
                if (!started) first = NR
                last = NR
                started = 1
            }
        }
        END {
            if (started) {
                for (i = first; i <= last; i++) print lines[i]
            }
        }
    '
}

write_declared_definition() {
    local config_file="$1"
    local target="$2"
    local content

    content="$(extract_declared_block "$config_file" "$target")"

    if [[ -z "$content" ]]; then
        echo "[SKIP] No content found for: $target"
        return 1
    fi

    mkdir -p "$(dirname -- "$target")"
    printf '%s\n' "$content" > "$target"
    chown root:root "$target"
    chmod 0644 "$target"

    echo "[CREATE] $target"
    ((created_count += 1))
}

create_svg_once() {
    local config_file="$1"

    (( svg_created )) && return 0

    local svg
    svg="$(
        awk -v target="$SVG_TARGET" '
            $0 == "# " target {
                in_svg_section = 1
                next
            }
            in_svg_section && /^# \// {
                exit
            }
            in_svg_section && /^cat > "\$ICON_FILE" <<'\''SVG'\''$/ {
                capture = 1
                next
            }
            capture && $0 == "SVG" {
                exit
            }
            capture {
                print
            }
        ' "$config_file"
    )"

    if [[ -z "$svg" ]]; then
        echo "[WARN] SVG definition not found in this input."
        return 1
    fi

    mkdir -p "$(dirname -- "$SVG_TARGET")"
    printf '%s\n' "$svg" > "$SVG_TARGET"
    chown root:root "$SVG_TARGET"
    chmod 0644 "$SVG_TARGET"

    echo "[CREATE] $SVG_TARGET"
    svg_created=1
    ((created_count += 1))
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

    [[ -n "$desktop" ]] || {
        echo "[WARN] No <Filename> found in shared menu definition."
        return 1
    }

    case "$desktop" in
        *-hash.desktop) ;;
        *)
            echo "[WARN] Ignoring non-hash menu entry declared by hash script: $desktop"
            return 1
            ;;
    esac

    for existing in "${HASH_MENU_ENTRIES[@]:-}"; do
        [[ "$existing" == "$desktop" ]] && return 0
    done

    HASH_MENU_ENTRIES+=("$desktop")
}

update_shared_menu_preserving_other_apps() {
    (( ${#HASH_MENU_ENTRIES[@]} > 0 )) || {
        echo "[WARN] No qualifying hash menu entries were found."
        return 0
    }

    mkdir -p "$(dirname -- "$MENU_TARGET")"

    if [[ -f "$MENU_TARGET" ]]; then
        local tmp entries desktop
        tmp="$(mktemp)"
        cp -a "$MENU_TARGET" "$tmp"

        # Remove only existing hash launcher entries.
        # Every other application definition is preserved untouched.
        sed -E -i \
            '/^[[:space:]]*<Filename>[^<]*-hash\.desktop<\/Filename>[[:space:]]*$/d' \
            "$tmp"

        if ! grep -q '<Include>' "$tmp" || ! grep -q '</Include>' "$tmp"; then
            echo "[ERROR] Existing $MENU_TARGET has no usable <Include>...</Include> block." >&2
            rm -f "$tmp"
            return 1
        fi

        entries=""
        for desktop in "${HASH_MENU_ENTRIES[@]}"; do
            entries+="      <Filename>${desktop}</Filename>"$'\n'
        done

        awk -v entries="$entries" '
            !done && /^[[:space:]]*<\/Include>[[:space:]]*$/ {
                printf "%s", entries
                done = 1
            }
            { print }
        ' "$tmp" > "${tmp}.new"

        mv "${tmp}.new" "$tmp"
        cp "$tmp" "$MENU_TARGET"
        rm -f "$tmp"

        chown root:root "$MENU_TARGET"
        chmod 0644 "$MENU_TARGET"

        echo "[UPDATE] $MENU_TARGET"
        echo "         Existing non-hash applications preserved."
        ((updated_count += 1))

    else
        {
            cat <<'MENU_HEAD'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
"http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">

<Menu>
  <Name>Applications</Name>

  <Menu>
    <Name>SignAndHash</Name>

    <Directory>sign-and-hash.directory</Directory>

    <Include>
MENU_HEAD

            local desktop
            for desktop in "${HASH_MENU_ENTRIES[@]}"; do
                printf '      <Filename>%s</Filename>\n' "$desktop"
            done

            cat <<'MENU_TAIL'
    </Include>

  </Menu>

</Menu>
MENU_TAIL
        } > "$MENU_TARGET"

        chown root:root "$MENU_TARGET"
        chmod 0644 "$MENU_TARGET"

        echo "[CREATE] $MENU_TARGET"
        ((created_count += 1))
    fi
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
                create_svg_once "$tmp" || true
                ;;
            "$MENU_TARGET")
                register_hash_menu_entry "$tmp" || true
                ;;
            *.desktop|*.directory)
                write_declared_definition "$tmp" "$target" || true
                ;;
            *.menu)
                write_declared_definition "$tmp" "$target" || true
                ;;
            *)
                echo "[SKIP] Unsupported declared target: $target"
                ;;
        esac
    done

    rm -f "$tmp"
    echo
done

# Shared Sign and Hash menu is modified exactly once per execution.
update_shared_menu_preserving_other_apps

update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true

echo
echo "===== INSTALL COMPLETE ====="
echo "Created:        $created_count"
echo "Updated:        $updated_count"
echo "Skipped inputs: $skipped_count"
