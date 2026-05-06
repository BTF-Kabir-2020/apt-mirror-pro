#!/bin/bash

# safer than set -e
set -o pipefail

# ───────── FILES ─────────
SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak"
# Ubuntu 24.04+ ships deb822 sources here; if left in place, apt merges them
# with sources.list and your mirror change appears "broken".
UBUNTU_SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
UBUNTU_SOURCES_BAK="/etc/apt/sources.list.d/ubuntu.sources.bak.apt-mirror-pro"
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

# Must match show_menu: Auto, Official, Regional, Reset, Custom, Show IR list, Exit
MENU_EXTRA=7

# ───────── GLOBAL COMMAND ─────────
create_command_link() {
    local script_path
    script_path="$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null)" || script_path="$(readlink -f "$0")"
    if [[ ! -f "/usr/local/bin/mirror" ]]; then
        ln -s "$script_path" "/usr/local/bin/mirror"
        chmod +x "/usr/local/bin/mirror"
        echo "${GREEN}✔ Command 'mirror' installed → /usr/local/bin/mirror${NC}"
    fi
}

# ───────── ROOT CHECK ─────────
[[ $EUID -ne 0 ]] && echo "${RED}Run as root${NC}" && exit 1

create_command_link

# ───────── BACKUP ─────────
backup_sources() {
    if [[ ! -f "$BACKUP_FILE" ]]; then
        if [[ -f "$SOURCES_FILE" ]]; then
            cp "$SOURCES_FILE" "$BACKUP_FILE"
        else
            : >"$BACKUP_FILE"
        fi
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
        return
    fi

    if [[ -f "$UBUNTU_SOURCES_BAK" ]]; then
        cp "$UBUNTU_SOURCES_BAK" "$UBUNTU_SOURCES"
        echo "${GREEN}✔ Restored ubuntu.sources (deb822)${NC}"
    fi

    refresh_apt_lists
}

# ───────── SYSTEM ─────────
get_codename() {
    local c
    c=$(lsb_release -cs 2>/dev/null) || true
    if [[ -n "$c" ]]; then
        echo "$c"
        return
    fi
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${VERSION_CODENAME:-jammy}"
        return
    fi
    echo "jammy"
}

get_current_mirror() {
    if [[ -f "$SOURCES_FILE" ]]; then
        grep -m1 "^deb " "$SOURCES_FILE" 2>/dev/null | awk '{print $2}'
    fi
}

validate_url() {
    [[ $1 =~ ^https?:// ]]
}

# ───────── UPDATE ─────────
disable_ubuntu_deb822_sources() {
    if [[ ! -f "$UBUNTU_SOURCES" ]]; then
        return 0
    fi
    if [[ ! -f "$UBUNTU_SOURCES_BAK" ]]; then
        cp "$UBUNTU_SOURCES" "$UBUNTU_SOURCES_BAK"
        echo "${GREEN}✔ Backed up $UBUNTU_SOURCES → $UBUNTU_SOURCES_BAK${NC}"
    fi
    rm -f "$UBUNTU_SOURCES"
    echo "${YELLOW}✔ Removed $UBUNTU_SOURCES so only sources.list applies (Ubuntu 24.04+ fix)${NC}"
}

refresh_apt_lists() {
    apt clean
    rm -rf /var/lib/apt/lists/*
}

update_sources() {
    local mirror=$1
    local codename=$(get_codename)
    local security_mirror

    validate_url "$mirror" || {
        echo "${RED}Invalid URL${NC}"
        return 1
    }

    [[ $mirror != */ ]] && mirror="${mirror}/"

    # security.ubuntu.com is often unreachable from restricted networks; use the
    # chosen mirror for -security unless switching to the official archive layout.
    if [[ "$mirror" == "$OFFICIAL" ]]; then
        security_mirror="http://security.ubuntu.com/ubuntu/"
    else
        security_mirror="$mirror"
    fi

    echo "${YELLOW}Switching to:${NC} $mirror"
    backup_sources
    disable_ubuntu_deb822_sources

    cat > "$SOURCES_FILE" <<EOF
deb $mirror $codename main restricted universe multiverse
deb $mirror $codename-updates main restricted universe multiverse
deb $mirror $codename-backports main restricted universe multiverse
deb $security_mirror $codename-security main restricted universe multiverse

deb-src $mirror $codename main restricted universe multiverse
deb-src $mirror $codename-updates main restricted universe multiverse
deb-src $mirror $codename-backports main restricted universe multiverse
deb-src $security_mirror $codename-security main restricted universe multiverse
EOF

    refresh_apt_lists
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
# ipapi.co and *.archive.ubuntu.com need global DNS/routing. On Iran national-only
# networks use the Iranian mirror entries or Auto (tests only IR mirrors).
get_regional() {
    local cc
    cc=$(curl -sS --max-time 3 https://ipapi.co/country 2>/dev/null | tr -d '[:space:]')
    if [[ ! "$cc" =~ ^[A-Za-z]{2}$ ]]; then
        cc="ir"
    fi
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
    echo "$i) Regional (by country)"
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
max_menu=$(( ${#MIRROR_NAMES[@]} + MENU_EXTRA ))

while true; do
    show_menu
    read -r choice

    if [[ ! $choice =~ ^[0-9]+$ ]] || (( choice < 1 || choice > max_menu )); then
        echo "${RED}Invalid option (1–$max_menu)${NC}"
        sleep 1
        continue
    fi

    if (( choice >= 1 && choice <= ${#MIRROR_NAMES[@]} )); then
        name="${MIRROR_NAMES[$((choice-1))]}"
        update_sources "${MIRROR_URLS[$name]}"
    else
        offset=$((choice - ${#MIRROR_NAMES[@]}))

        case $offset in
            1) auto_select ;;
            2) update_sources "$OFFICIAL" ;;
            3)
                echo "${YELLOW}Resolving regional mirror...${NC}"
                update_sources "$(get_regional)"
                ;;
            4) reset_sources ;;
            5)
                read -rp "Enter URL: " u
                update_sources "$u"
                ;;
            6)
                curl -s "$MIRRORS_LIST_URL"
                read -rp "Enter..."
                continue
                ;;
            7) exit 0 ;;
            *)
                echo "${RED}Internal menu mismatch (offset $offset)${NC}"
                sleep 1
                continue
                ;;
        esac
    fi

    echo "${YELLOW}Running apt update...${NC}"
    apt update || echo "${RED}apt failed${NC}"

    read -rp "Enter..."
done