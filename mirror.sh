#!/bin/bash

# safer than set -e
set -o pipefail

# ───────── FILES ─────────
SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak"
MIRRORS_LIST_URL="http://mirrors.ubuntu.com/IR.txt"

# ───────── COLORS ─────────
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

# ───────── MIRRORS ─────────
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
["ArvanCloud"]="http://mirror.arvancloud.ir/ubuntu/"
["IranServer"]="http://mirror.iranserver.com/ubuntu/"
["LinuxMirrors"]="http://repo.linuxmirrors.ir/ubuntu/"
["Pishgaman"]="http://ubuntu.pishgaman.net/ubuntu/"
["Sindad"]="http://ir.ubuntu.sindad.cloud/ubuntu/"
["Shatel"]="http://ubuntu.shatel.ir/ubuntu/"
["HostIran"]="http://ubuntu.hostiran.ir/ubuntu/"
["IUT"]="http://repo.iut.ac.ir/repo/Ubuntu/"
["Faraso"]="http://mirror.faraso.org/ubuntu/"
["ParsVDS"]="http://ubuntu.parsvds.com/ubuntu/"
)

OFFICIAL="http://archive.ubuntu.com/ubuntu/"

# ───────── ROOT CHECK ─────────
[[ $EUID -ne 0 ]] && echo "${RED}Run as root${NC}" && exit 1

# ───────── BACKUP ─────────
backup_sources() {
    if [[ ! -f "$BACKUP_FILE" ]]; then
        cp "$SOURCES_FILE" "$BACKUP_FILE"
        echo "${GREEN}✔ Backup created${NC}"
    fi
}

# ───────── RESET ─────────
reset_sources() {
    echo "${YELLOW}Resetting sources...${NC}"

    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$SOURCES_FILE"
        echo "${GREEN}✔ Restored backup${NC}"
    else
        echo "${YELLOW}No backup → using official${NC}"
        update_sources "$OFFICIAL"
    fi

    apt update
}

# ───────── SYSTEM ─────────
get_codename() {
    lsb_release -cs 2>/dev/null || echo "jammy"
}

get_current_mirror() {
    grep -m1 "^deb " "$SOURCES_FILE" | awk '{print $2}'
}

validate_url() {
    [[ $1 =~ ^https?:// ]]
}

# ───────── UPDATE ─────────
update_sources() {
    local mirror=$1
    local codename=$(get_codename)

    validate_url "$mirror" || {
        echo "${RED}Invalid URL${NC}"
        return 1
    }

    [[ $mirror != */ ]] && mirror="${mirror}/"

    echo "${YELLOW}Switching to:${NC} $mirror"
    backup_sources

    cat > "$SOURCES_FILE" <<EOF
deb $mirror $codename main restricted universe multiverse
deb $mirror $codename-updates main restricted universe multiverse
deb $mirror $codename-backports main restricted universe multiverse

deb-src $mirror $codename main restricted universe multiverse
deb-src $mirror $codename-updates main restricted universe multiverse
deb-src $mirror $codename-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse
EOF

    echo "${GREEN}✔ Updated successfully${NC}"
}

# ───────── SPEED TEST ─────────
speed_test() {
    local url="$1/dists/$(get_codename)/Release"

    curl -L -s -o /dev/null \
        --connect-timeout 2 \
        --max-time 5 \
        -w "%{time_total}" "$url"
}

# ───────── AUTO SELECT ─────────
auto_select() {
    echo "${YELLOW}Finding fastest mirror...${NC}"

    local best=""
    local best_time=999

    for name in "${MIRROR_NAMES[@]}"; do
        m="${MIRROR_URLS[$name]}"

        echo -n "Testing $name ... "

        t=$(speed_test "$m")

        if [[ -z "$t" || "$t" == "0.000" ]]; then
            echo "${RED}FAIL${NC}"
            continue
        fi

        echo "${GREEN}${t}s${NC}"

        if awk "BEGIN {exit !($t < $best_time)}"; then
            best_time=$t
            best=$m
        fi
    done

    if [[ -z "$best" ]]; then
        echo "${RED}No working mirror found${NC}"
        return 1
    fi

    echo "${GREEN}Best: $best (${best_time}s)${NC}"
    update_sources "$best"
}

# ───────── REGIONAL ─────────
get_regional() {
    cc=$(curl -s --max-time 3 https://ipapi.co/country || echo "us")
    echo "http://${cc,,}.archive.ubuntu.com/ubuntu/"
}

# ───────── MENU ─────────
show_menu() {
    clear
    echo "${GREEN}APT Mirror Pro (Fixed)${NC}"
    echo "Current: $(get_current_mirror)"
    echo

    i=1
    for name in "${MIRROR_NAMES[@]}"; do
        echo "$i) $name"
        ((i++))
    done

    echo "$i) Auto"
    ((i++))
    echo "$i) Official"
    ((i++))
    echo "$i) Reset"
    ((i++))
    echo "$i) Custom"
    ((i++))
    echo "$i) Show IR list"
    ((i++))
    echo "$i) Exit"
}

# ───────── MAIN LOOP ─────────
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
            2) update_sources "$OFFICIAL" ;;
            3) reset_sources ;;
            4)
                read -rp "Enter URL: " u
                update_sources "$u"
                ;;
            5)
                curl -s "$MIRRORS_LIST_URL"
                read -rp "Enter..."
                ;;
            6) exit ;;
        esac
    fi

    echo "${YELLOW}Running apt update...${NC}"
    apt update || echo "${RED}apt failed${NC}"

    read -rp "Enter..."
done