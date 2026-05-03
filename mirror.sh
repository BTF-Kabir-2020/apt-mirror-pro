#!/bin/bash

set -e

# ───────────────────────── FLAGS ─────────────────────────
INSTALL_GLOBAL=0
SILENT=0

for arg in "$@"; do
    case $arg in
        --install-global) INSTALL_GLOBAL=1 ;;
        --silent) SILENT=1 ;;
    esac
done

# ───────────────────────── FILES ─────────────────────────
SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak.mirror-pro"
MIRRORS_LIST_URL="http://mirrors.ubuntu.com/IR.txt"

# ───────────────────────── COLORS ─────────────────────────
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

# ───────────────────────── MIRRORS ─────────────────────────
MIRROR_NAMES=(
"ArvanCloud"
"IranServer"
"LinuxMirrors"
"Pishgaman"
"Sindad"
"Shatel"
"HostIran"
"IUT"
"Faraso"
"ParsVDS"
)

declare -A MIRROR_URLS=(
["ArvanCloud"]="https://mirror.arvancloud.ir/ubuntu/"
["IranServer"]="https://mirror.iranserver.com/ubuntu/"
["LinuxMirrors"]="https://repo.linuxmirrors.ir/ubuntu/"
["Pishgaman"]="https://ubuntu.pishgaman.net/ubuntu/"
["Sindad"]="https://ir.ubuntu.sindad.cloud/ubuntu/"
["Shatel"]="https://ubuntu.shatel.ir/ubuntu/"
["HostIran"]="https://ubuntu.hostiran.ir/ubuntu/"
["IUT"]="https://repo.iut.ac.ir/repo/Ubuntu/"
["Faraso"]="https://mirror.faraso.org/ubuntu/"
["ParsVDS"]="https://ubuntu.parsvds.com/ubuntu/"
)

# ───────────────────────── ROOT CHECK ─────────────────────────
[[ $EUID -ne 0 ]] && echo "${RED}Run as root${NC}" && exit 1

# ───────────────────────── GLOBAL COMMAND ─────────────────────────
create_command_link() {
    local target="/usr/local/bin/mirror"
    local source
    source="$(readlink -f "$0")"

    if [[ "$INSTALL_GLOBAL" -ne 1 ]]; then
        return
    fi

    if [[ "$SILENT" -ne 1 ]]; then
        read -rp "Install global command 'mirror'? (y/n): " ans
        [[ ! "$ans" =~ ^[Yy]$ ]] && return
    fi

    rm -f "$target"
    ln -s "$source" "$target"
    chmod +x "$target"

    [[ "$SILENT" -ne 1 ]] && echo "✔ mirror command installed"
}

create_command_link

# ───────────────────────── BACKUP ─────────────────────────
backup_sources() {
    [[ -f "$BACKUP_FILE" ]] || cp "$SOURCES_FILE" "$BACKUP_FILE"
}

# ───────────────────────── CONFIRM ─────────────────────────
confirm_change() {
    [[ "$SILENT" -eq 1 ]] && return

    echo
    echo "${YELLOW}⚠ You are modifying APT sources${NC}"
    read -rp "Continue? (y/N): " c

    [[ ! "$c" =~ ^[Yy]$ ]] && echo "${RED}Cancelled${NC}" && exit 0
}

# ───────────────────────── SYSTEM ─────────────────────────
get_codename() {
    lsb_release -cs
}

validate_url() {
    [[ $1 =~ ^https?:// ]]
}

get_current_mirror() {
    grep -m 1 "^deb " "$SOURCES_FILE" 2>/dev/null | awk '{print $2}'
}

# ───────────────────────── UPDATE ─────────────────────────
update_sources() {
    local mirror=$1
    local codename

    codename=$(get_codename)

    validate_url "$mirror" || { echo "Invalid URL"; return 1; }

    [[ $mirror != */ ]] && mirror="${mirror}/"

    confirm_change
    backup_sources

    cat > "$SOURCES_FILE" <<EOF
deb $mirror $codename main restricted universe multiverse
deb $mirror $codename-updates main restricted universe multiverse
deb $mirror $codename-backports main restricted universe multiverse
deb-src $mirror $codename main restricted universe multiverse
deb-src $mirror $codename-updates main restricted universe multiverse
deb-src $mirror $codename-backports main restricted universe multiverse

deb https://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse
EOF

    echo "${GREEN}Updated -> $mirror${NC}"
}

# ───────────────────────── SPEED TEST ─────────────────────────
speed_test() {
    curl -o /dev/null -s -w "%{time_total}" \
    --connect-timeout 2 --max-time 3 \
    "$1/dists/$(get_codename)/Release"
}

# ───────────────────────── AUTO SELECT ─────────────────────────
auto_select() {
    echo "${YELLOW}Selecting best mirror...${NC}"

    local best=""
    local best_time=999

    for m in "${MIRROR_URLS[@]}"; do
        echo -n "Testing $m ... "

        t=$(speed_test "$m")

        [[ -z "$t" ]] && { echo "FAIL"; continue; }

        echo "${GREEN}${t}s${NC}"

        if awk "BEGIN {exit !($t < $best_time)}"; then
            best_time=$t
            best=$m
        fi
    done

    [[ -z "$best" ]] && echo "No mirror found" && return 1

    echo "${GREEN}Best Mirror: $best${NC}"
    update_sources "$best"
}

# ───────────────────────── REGIONAL ─────────────────────────
get_regional() {
    cc=$(curl -s https://ipapi.co/country || echo "us")
    echo "https://${cc,,}.archive.ubuntu.com/ubuntu/"
}

# ───────────────────────── RESET (NEW) ─────────────────────────
reset_sources() {
    echo
    echo "${YELLOW}Reset Options:${NC}"
    echo "1) Restore backup"
    echo "2) Official Ubuntu defaults"
    read -rp "Choose: " r

    case $r in
        1)
            [[ -f "$BACKUP_FILE" ]] || { echo "No backup found"; return 1; }
            cp "$BACKUP_FILE" "$SOURCES_FILE"
            echo "${GREEN}✔ Restored backup${NC}"
            ;;
        2)
            codename=$(get_codename)
            cat > "$SOURCES_FILE" <<EOF
deb http://archive.ubuntu.com/ubuntu $codename main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $codename-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $codename-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse
EOF
            echo "${GREEN}✔ Reset to official Ubuntu${NC}"
            ;;
    esac
}

# ───────────────────────── MENU ─────────────────────────
show_menu() {
    clear
    echo "${GREEN}APT Mirror Pro${NC}"
    echo "Current: $(get_current_mirror)"
    echo

    i=1
    for name in "${MIRROR_NAMES[@]}"; do
        echo "$i) $name"
        ((i++))
    done

    echo "$i) Auto"; ((i++))
    echo "$i) Official Ubuntu"; ((i++))
    echo "$i) Regional"; ((i++))
    echo "$i) Custom"; ((i++))
    echo "$i) Show IR list"; ((i++))
    echo "$i) Reset APT sources"; ((i++))
    echo "$i) Exit"
}

# ───────────────────────── MAIN LOOP ─────────────────────────
while true; do
    show_menu
    read -r choice

    if (( choice >= 1 && choice <= ${#MIRROR_NAMES[@]} )); then
        name="${MIRROR_NAMES[$((choice-1))]}"
        update_sources "${MIRROR_URLS[$name]}"
        continue
    fi

    case "$choice" in
        $(( ${#MIRROR_NAMES[@]} + 1 ))) auto_select ;;
        $(( ${#MIRROR_NAMES[@]} + 2 ))) update_sources "https://archive.ubuntu.com/ubuntu/" ;;
        $(( ${#MIRROR_NAMES[@]} + 3 ))) update_sources "$(get_regional)" ;;
        $(( ${#MIRROR_NAMES[@]} + 4 )))
            read -rp "Enter URL: " u
            update_sources "$u"
            ;;
        $(( ${#MIRROR_NAMES[@]} + 5 )))
            clear
            echo "🇮🇷 IR Mirrors:"
            curl -s "$MIRRORS_LIST_URL" | nl -ba
            read -rp "Press Enter..."
            ;;
        $(( ${#MIRROR_NAMES[@]} + 6 ))) reset_sources ;;
        $(( ${#MIRROR_NAMES[@]} + 7 ))) exit ;;
        *)
            echo "Invalid choice"
            ;;
    esac

    echo "${YELLOW}Running apt update...${NC}"
    apt update || echo "${RED}apt update failed${NC}"

    read -rp "Press Enter..."
done