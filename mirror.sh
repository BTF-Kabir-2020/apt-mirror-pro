#!/bin/bash

set -e

# ───────────────────────── FLAGS ─────────────────────────
INSTALL_GLOBAL=0
SILENT=0

for arg in "$@"; do
    case $arg in
        --install-global)
            INSTALL_GLOBAL=1
            ;;
        --silent)
            SILENT=1
            ;;
    esac
done

# ───────────────────────── FILES ─────────────────────────
SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak"
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

# ───────────────────────── GLOBAL INSTALL ─────────────────────────
create_command_link() {
    local target="/usr/local/bin/mirror"
    local source
    source="$(readlink -f "$0")"

    if [[ "$INSTALL_GLOBAL" -ne 1 ]]; then
        return
    fi

    if [[ "$SILENT" -ne 1 ]]; then
        echo "Do you want to install global command 'mirror'? (y/n)"
        read -r ans

        if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
            echo "Skipping global install."
            return
        fi
    fi

    if [[ -L "$target" || -e "$target" ]]; then
        rm -f "$target"
    fi

    ln -s "$source" "$target"
    chmod +x "$target"

    [[ "$SILENT" -ne 1 ]] && echo "✔ Global command installed: mirror"
}

create_command_link

# ───────────────────────── BACKUP ─────────────────────────
backup_sources() {
    if [[ ! -f "$BACKUP_FILE" ]]; then
        cp "$SOURCES_FILE" "$BACKUP_FILE"
        echo "${GREEN}Backup created${NC}"
    fi
}

# ───────────────────────── CONFIRM ─────────────────────────
confirm_change() {
    if [[ "$SILENT" -eq 1 ]]; then
        return
    fi

    echo
    echo "${YELLOW}⚠ You are modifying system APT sources${NC}"
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
    grep -m 1 "^deb " "$SOURCES_FILE" | awk '{print $2}'
}

# ───────────────────────── UPDATE ─────────────────────────
update_sources() {
    local mirror=$1
    local codename

    codename=$(get_codename)

    validate_url "$mirror" || { echo "${RED}Invalid URL${NC}"; return 1; }

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
    curl --max-time 3 -o /dev/null -s -w "%{time_total}" "$1/dists/$(get_codename)/Release"
}

# ───────────────────────── AUTO SELECT ─────────────────────────
auto_select() {
    echo "${YELLOW}Selecting best mirror...${NC}"

    local best=""
    local best_time=999

    for m in "${MIRROR_URLS[@]}"; do
        echo -n "Testing $m ... "

        t=$(speed_test "$m")

        [[ -z "$t" || "$t" == "0.000" ]] && { echo "${RED}FAIL${NC}"; continue; }

        echo "${GREEN}${t}s${NC}"

        if awk "BEGIN {exit !($t < $best_time)}"; then
            best_time=$t
            best=$m
        fi
    done

    [[ -z "$best" ]] && echo "${RED}No mirror found${NC}" && return 1

    echo "${GREEN}Best Mirror: $best${NC}"
    update_sources "$best"
}

# ───────────────────────── REGIONAL ─────────────────────────
get_regional() {
    cc=$(curl --max-time 3 -s https://ipapi.co/country || echo "us")
    echo "https://${cc,,}.archive.ubuntu.com/ubuntu/"
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

    echo "$i) Auto"
    ((i++))
    echo "$i) Official Ubuntu"
    ((i++))
    echo "$i) Regional"
    ((i++))
    echo "$i) Custom"
    ((i++))
    echo "$i) Show IR list"
    ((i++))
    echo "$i) Exit"
}

# ───────────────────────── MAIN LOOP ─────────────────────────
while true; do
    show_menu
    read -r choice

    if (( choice >= 1 && choice <= ${#MIRROR_NAMES[@]} )); then
        name="${MIRROR_NAMES[$((choice-1))]}"
        update_sources "${MIRROR_URLS[$name]}"

    else
        offset=$((choice - ${#MIRROR_NAMES[@]}))

        case $offset in
            1) auto_select ;;
            2) update_sources "https://archive.ubuntu.com/ubuntu/" ;;
            3) update_sources "$(get_regional)" ;;
            4)
                read -rp "Enter URL: " u
                update_sources "$u"
                ;;
            5)
                curl --max-time 5 -s "$MIRRORS_LIST_URL"
                read -rp "Press Enter..."
                ;;
            6) exit ;;
        esac
    fi

    echo "${YELLOW}Running apt update...${NC}"
    apt update || echo "${RED}apt update failed${NC}"

    read -rp "Press Enter..."
done