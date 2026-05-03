#!/bin/bash

set -e

SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak"
MIRRORS_LIST_URL="http://mirrors.ubuntu.com/IR.txt"

GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
NC=$'\e[0m'

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

# Root check
[[ $EUID -ne 0 ]] && echo "${RED}Run as root${NC}" && exit 1

# Create shortcut
create_command_link() {
    if [[ ! -f "/usr/local/bin/mirror" ]]; then
        ln -s "$(readlink -f "$0")" "/usr/local/bin/mirror"
        chmod +x "/usr/local/bin/mirror"
    fi
}

create_command_link

# Backup
backup_sources() {
    if [[ ! -f "$BACKUP_FILE" ]]; then
        cp "$SOURCES_FILE" "$BACKUP_FILE"
        echo "${GREEN}Backup created${NC}"
    fi
}

# Get codename
get_codename() {
    lsb_release -cs
}

# Validate URL
validate_url() {
    [[ $1 =~ ^https?:// ]]
}

# Get current mirror
get_current_mirror() {
    grep -m 1 "^deb " "$SOURCES_FILE" | awk '{print $2}'
}

# Update sources
update_sources() {
    local mirror=$1
    local codename=$(get_codename)

    if ! validate_url "$mirror"; then
        echo "${RED}Invalid URL${NC}"
        return 1
    fi

    [[ $mirror != */ ]] && mirror="${mirror}/"

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

# Speed test (with timeout)
speed_test() {
    curl --max-time 3 -o /dev/null -s -w "%{time_total}" "$1/dists/$(get_codename)/Release"
}

# Auto select best mirror
auto_select() {
    echo "${YELLOW}Selecting best mirror...${NC}"

    local best=""
    local best_time=999

    for m in "${MIRROR_URLS[@]}"; do
        echo -n "Testing $m ... "

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
        echo "${RED}No working mirror found!${NC}"
        return 1
    fi

    echo "${GREEN}Best Mirror: $best${NC}"
    update_sources "$best"
}

# Regional mirror
get_regional() {
    cc=$(curl --max-time 3 -s https://ipapi.co/country)
    echo "https://${cc,,}.archive.ubuntu.com/ubuntu/"
}

# Menu
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

    echo "$i) Auto (Best)" ; ((i++))
    echo "$i) Official Ubuntu" ; ((i++))
    echo "$i) Regional" ; ((i++))
    echo "$i) Custom" ; ((i++))
    echo "$i) Show IR list" ; ((i++))
    echo "$i) Exit"
}

# Main loop
while true; do
    show_menu
    read -r choice

    max=$((${#MIRROR_NAMES[@]} + 6))

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
                read -rp "Enter to continue..."
                continue
                ;;
            6) exit ;;
        esac
    fi

    echo "${YELLOW}Updating package list...${NC}"
    apt update || echo "${RED}apt update failed${NC}"

    read -rp "Enter to continue..."
done