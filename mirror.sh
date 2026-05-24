#!/bin/bash

# safer than set -e
set -o pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ───────── FILES ─────────
SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.bak"
UBUNTU_SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
UBUNTU_SOURCES_BAK="/etc/apt/sources.list.d/ubuntu.sources.bak.apt-mirror-pro"
MIRRORS_LIST_URL="http://mirrors.ubuntu.com/IR.txt"
CONFIG_DIR="/etc/apt-mirror-pro"
CUSTOM_MIRRORS_FILE="$CONFIG_DIR/custom_mirrors.conf"
STATE_FILE="$CONFIG_DIR/state.env"
BACKUP_SNAPSHOT_DIR="$CONFIG_DIR/backups"

UA="Mozilla/5.0 (X11; Ubuntu; Linux x86_64)"
MAX_RETRIES=2
VALIDATION_RETRIES=3
PROBE_MIRROR_MAX=2
PROBE_CONNECT=1
PROBE_MAX=2
PROBE_SPEED_BYTES=262144

# ───────── COLORS ─────────
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
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
"AsiaTech"
"ManageIT"
"Pardisco"
"BardiaTech"
"ZeroOneCloud"
"ByteIran"
"Rasanegar"
"KubarCloud"
"Abrha"
"EnMirror"
"Afranet"
"Chabokan"
"IranArchive"
"Petiak"
"ITO-Archive"
"Runflare"
)

declare -A MIRROR_URLS=(
["ArvanCloud"]="https://mirror.arvancloud.ir/ubuntu/"
["IranServer"]="https://mirror.iranserver.com/ubuntu/"
["LinuxMirrors"]="http://repo.linuxmirrors.ir/ubuntu/"
["Pishgaman"]="http://ubuntu.pishgaman.net/ubuntu/"
["Sindad"]="https://ir.ubuntu.sindad.cloud/ubuntu/"
["Shatel"]="http://mirror.shatel.ir/ubuntu/"
["HostIran"]="https://ubuntu.hostiran.ir/ubuntu/"
["IUT"]="http://repo.iut.ac.ir/repo/Ubuntu/"
["Faraso"]="http://mirror.faraso.org/ubuntu/"
["ParsVDS"]="http://ubuntu.parsvds.com/ubuntu/"
["AsiaTech"]="http://mirror.asiatech.ir/ubuntu/"
["ManageIT"]="https://mirror.manageit.ir/ubuntu/"
["Pardisco"]="https://mirrors.pardisco.co/ubuntu/"
["BardiaTech"]="https://ubuntu.bardia.tech/"
["ZeroOneCloud"]="https://mirror.0-1.cloud/ubuntu/"
["ByteIran"]="http://ubuntu.byteiran.com/ubuntu/"
["Rasanegar"]="https://mirror.rasanegar.com/ubuntu/"
["KubarCloud"]="https://mirrors.kubarcloud.com/ubuntu/"
["Abrha"]="https://repo.abrha.net/ubuntu/"
["EnMirror"]="https://en-mirror.ir/ubuntu/"
["Afranet"]="https://mirror.afranet.com/ubuntu/"
["Chabokan"]="https://iran.chabokan.net/ubuntu/"
["IranArchive"]="https://ir.archive.ubuntu.com/ubuntu/"
["Petiak"]="https://archive.ubuntu.petiak.ir/ubuntu/"
["ITO-Archive"]="https://archive.ito.gov.ir/ubuntu/ubuntu/"
["Runflare"]="https://mirror-linux.runflare.com/ubuntu/"
)

# Separate security base (e.g. Shatel uses ubuntu-security host)
declare -A MIRROR_SECURITY_URLS=(
["Shatel"]="http://mirror.shatel.ir/ubuntu-security/"
)

OFFICIAL="http://archive.ubuntu.com/ubuntu/"

# Auto, Official, Regional, Reset, Custom, Show IR list, Manage backups, Exit
MENU_EXTRA=8

SKIP_REQUESTED=false
OLD_STTY=""

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

mkdir -p "$CONFIG_DIR" "$BACKUP_SNAPSHOT_DIR"
touch "$CUSTOM_MIRRORS_FILE" 2>/dev/null || true

# ───────── DEPS & CUSTOM MIRRORS ─────────
ensure_deps() {
    local pkgs=()
    command -v curl >/dev/null 2>&1 || pkgs+=("curl")
    if [[ ${#pkgs[@]} -gt 0 ]]; then
        apt update >/dev/null 2>&1 || true
        apt install -y "${pkgs[@]}" >/dev/null 2>&1 || true
    fi
}

load_custom_mirrors() {
    [[ -f "$CUSTOM_MIRRORS_FILE" ]] || return 0
    while IFS='|' read -r cname curl csec; do
        [[ -z "$cname" || "$cname" =~ ^[[:space:]]*# ]] && continue
        cname="${cname#"${cname%%[![:space:]]*}"}"
        cname="${cname%"${cname##*[![:space:]]}"}"
        curl="${curl#"${curl%%[![:space:]]*}"}"
        curl="${curl%"${curl##*[![:space:]]}"}"
        [[ -z "$curl" ]] && continue
        MIRROR_NAMES+=("$cname")
        MIRROR_URLS["$cname"]="$curl"
        if [[ -n "${csec// }" ]]; then
            MIRROR_SECURITY_URLS["$cname"]="$csec"
        fi
    done <"$CUSTOM_MIRRORS_FILE"
}

load_state() {
    LAST_BEST_NAME=""
    LAST_BEST_URL=""
    LAST_BEST_MS=""
    LAST_BEST_SPEED_KBPS=""
    LAST_SCORE=""
    LAST_RUN_AT=""
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$STATE_FILE"
    fi
}

save_state() {
    cat >"$STATE_FILE" <<EOF
LAST_BEST_NAME="${LAST_BEST_NAME:-}"
LAST_BEST_URL="${LAST_BEST_URL:-}"
LAST_BEST_MS="${LAST_BEST_MS:-}"
LAST_BEST_SPEED_KBPS="${LAST_BEST_SPEED_KBPS:-}"
LAST_SCORE="${LAST_SCORE:-}"
LAST_RUN_AT="${LAST_RUN_AT:-}"
EOF
}

ensure_deps
load_custom_mirrors
load_state

# ───────── NON-BLOCKING SKIP (during Auto test) ─────────
setup_nonblock_input() {
    OLD_STTY=$(stty -g 2>/dev/null || true)
    stty -echo -icanon min 0 time 0 2>/dev/null || true
}

restore_input() {
    [[ -n "$OLD_STTY" ]] && stty "$OLD_STTY" 2>/dev/null || true
}

check_skip() {
    local ch
    ch=$(dd bs=1 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [[ "$ch" == "0a" || "$ch" == "0d" ]]; then
        SKIP_REQUESTED=true
    fi
}

# ───────── MIRROR VALIDATION ─────────
check_suite() {
    local base="$1" suite="$2" retry="${3:-0}"
    local url="${base%/}/dists/$suite/InRelease"
    local code

    code=$(curl -4 --ipv4 -A "$UA" -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 6 --max-time 10 -L "$url" 2>/dev/null || echo "000")

    if [[ "$code" != "200" ]] && [[ $retry -lt $MAX_RETRIES ]]; then
        sleep 1
        check_suite "$base" "$suite" $((retry + 1))
        return $?
    fi

    [[ "$code" == "200" ]]
}

check_suite_probe() {
    local base="$1" suite="$2"
    local url="${base%/}/dists/$suite/InRelease"
    local code

    code=$(curl -4 --ipv4 -A "$UA" -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$PROBE_CONNECT" --max-time "$PROBE_MAX" -L "$url" 2>/dev/null || echo "000")
    [[ "$code" == "200" ]]
}

get_arch() {
    dpkg --print-architecture 2>/dev/null || echo "amd64"
}

detect_apt_busy_pids() {
    {
        fuser /var/lib/apt/lists/lock 2>/dev/null || true
        fuser /var/lib/dpkg/lock-frontend 2>/dev/null || true
        pgrep -x apt 2>/dev/null || true
        pgrep -x apt-get 2>/dev/null || true
        pgrep -x unattended-upgrade 2>/dev/null || true
    } | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' '
}

wait_for_apt_lock() {
    local max_wait="${1:-30}" waited=0
    while [[ -n "$(detect_apt_busy_pids)" ]]; do
        (( waited >= max_wait )) && return 1
        sleep 1
        waited=$((waited + 1))
    done
    return 0
}

backup_full_apt() {
    local dir="$BACKUP_SNAPSHOT_DIR/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dir"
    [[ -f "$SOURCES_FILE" ]] && cp -a "$SOURCES_FILE" "$dir/" || true
    [[ -d /etc/apt/sources.list.d ]] && cp -a /etc/apt/sources.list.d "$dir/" || true
    echo "$dir"
}

rollback_latest_snapshot() {
    local last
    last=$(ls -1dt "$BACKUP_SNAPSHOT_DIR"/* 2>/dev/null | head -n1 || true)
    [[ -z "$last" || ! -d "$last" ]] && {
        echo "${RED}No full backup snapshot found.${NC}"
        return 1
    }
    echo "${YELLOW}Rolling back from:${NC} $last"
    [[ -f "$last/sources.list" ]] && cp -a "$last/sources.list" "$SOURCES_FILE" || true
    if [[ -d "$last/sources.list.d" ]]; then
        rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
        cp -a "$last/sources.list.d/." /etc/apt/sources.list.d/ || true
    fi
    refresh_apt_lists
    echo "${GREEN}✔ Rollback applied${NC}"
    return 0
}

validate_mirror() {
    local base="${1%/}"
    local codename arch
    codename=$(get_codename)
    arch=$(get_arch)
    local test_file="$base/dists/$codename/main/binary-${arch}/Packages.gz"
    local size i

    for ((i = 1; i <= VALIDATION_RETRIES; i++)); do
        size=$(curl -4 --ipv4 -A "$UA" -sL --connect-timeout 5 --max-time 8 \
            -w "%{size_download}" -o /dev/null "$test_file" 2>/dev/null || echo "0")

        if [[ "${size:-0}" -gt 500000 ]]; then
            return 0
        fi

        [[ $i -lt $VALIDATION_RETRIES ]] && sleep 2
    done

    return 1
}

is_mirror_syncing() {
    local base="${1%/}"
    local codename
    codename=$(get_codename)
    local inrelease_url="$base/dists/$codename/InRelease"
    local last_modified mod_epoch now_epoch diff

    last_modified=$(curl -4 --ipv4 -A "$UA" -sI --connect-timeout 5 \
        "$inrelease_url" 2>/dev/null | grep -i "last-modified:" | cut -d' ' -f2-)

    if [[ -n "$last_modified" ]]; then
        mod_epoch=$(date -d "$last_modified" +%s 2>/dev/null || echo "0")
        now_epoch=$(date +%s)
        diff=$((now_epoch - mod_epoch))
        [[ $diff -lt 900 ]]
    else
        return 1
    fi
}

# ───────── BACKUP ─────────
backup_sources() {
    local ts
    ts=$(date +%F-%H%M%S)

    if [[ ! -f "$BACKUP_FILE" ]]; then
        if [[ -f "$SOURCES_FILE" ]]; then
            cp "$SOURCES_FILE" "$BACKUP_FILE"
        else
            : >"$BACKUP_FILE"
        fi
        echo "${GREEN}✔ Initial backup created ($BACKUP_FILE)${NC}"
    fi

    if [[ -f "$SOURCES_FILE" ]]; then
        cp "$SOURCES_FILE" "${SOURCES_FILE}.bak.${ts}"
    fi
}

backup_ubuntu_sources() {
    local ts
    ts=$(date +%F-%H%M%S)

    if [[ ! -f "$UBUNTU_SOURCES" ]]; then
        return 0
    fi

    if [[ ! -f "$UBUNTU_SOURCES_BAK" ]]; then
        cp "$UBUNTU_SOURCES" "$UBUNTU_SOURCES_BAK"
    fi

    cp "$UBUNTU_SOURCES" "${UBUNTU_SOURCES}.bak.${ts}"
}

manage_backups() {
    local -a backups=()
    local bfile bdate mirrors i BCHOICE SELECTED_BACKUP ORIGINAL_FILE
    local PRE_RESTORE_BACKUP CONFIRM raw_lines

    echo "${BLUE}====================================${NC}"
    echo "${BLUE}Backup Manager${NC}"
    echo "${BLUE}====================================${NC}"

    mapfile -t backups < <(
        {
            ls "${SOURCES_FILE}.bak."* 2>/dev/null || true
            ls /etc/apt/sources.list.d/ubuntu.sources.bak.* 2>/dev/null || true
            [[ -f "$BACKUP_FILE" ]] && echo "$BACKUP_FILE"
            [[ -f "$UBUNTU_SOURCES_BAK" ]] && echo "$UBUNTU_SOURCES_BAK"
        } | grep -v '^$' | sort -ru
    )

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "${YELLOW}No backups found.${NC}"
        echo "Backups are created automatically when you change your mirror."
        echo
        return
    fi

    echo "Found ${GREEN}${#backups[@]}${NC} backup(s):"
    echo

    for i in "${!backups[@]}"; do
        bfile="${backups[$i]}"
        bdate=$(basename "$bfile" | sed -E 's/.*\.bak\.([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]{6})/\1 \2:00:00/; t; s/.*\.bak$/(initial backup)/')

        mirrors=$(grep -E '^deb' "$bfile" 2>/dev/null \
            | sed -E 's/^(deb(-src)?)[[:space:]]+(\[[^]]*\][[:space:]]+)?//' \
            | awk '{print $1}' | grep -E '^https?://' | sort -u | tr '\n' ' ' || true)
        if [[ -z "${mirrors// /}" ]]; then
            mirrors=$(grep -E '^URIs:' "$bfile" 2>/dev/null \
                | sed 's/^URIs:[[:space:]]*//' | tr ' ' '\n' \
                | grep -E '^https?://' | sort -u | tr '\n' ' ' || true)
        fi
        [[ -z "${mirrors// /}" ]] && mirrors="(unknown format)"

        echo "  $((i + 1)). ${YELLOW}$bdate${NC}"
        echo "     File: $bfile"
        echo "     Mirrors: ${GREEN}$mirrors${NC}"
        echo
    done

    read -rp "Enter backup number to restore (or 'q' to go back): " BCHOICE

    [[ "$BCHOICE" == "q" ]] && echo "Cancelled." && return

    if [[ ! "$BCHOICE" =~ ^[0-9]+$ ]] || (( BCHOICE < 1 || BCHOICE > ${#backups[@]} )); then
        echo "${RED}Invalid choice.${NC}"
        return
    fi

    SELECTED_BACKUP="${backups[$((BCHOICE - 1))]}"

    echo
    echo "${BLUE}Selected backup:${NC} $SELECTED_BACKUP"
    echo "${YELLOW}Content preview:${NC}"
    {
        grep -E '^deb' "$SELECTED_BACKUP" 2>/dev/null || true
        grep -E '^URIs:|^Suites:|^Components:|^Types:' "$SELECTED_BACKUP" 2>/dev/null || true
    } | sort -u | while read -r line; do
        echo "  ${GREEN}$line${NC}"
    done
    echo

    read -rp "Restore this backup? (y/N): " CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "Cancelled." && return

    if [[ "$SELECTED_BACKUP" == *"ubuntu.sources"* ]]; then
        ORIGINAL_FILE="$UBUNTU_SOURCES"
    else
        ORIGINAL_FILE="$SOURCES_FILE"
    fi

    PRE_RESTORE_BACKUP="${ORIGINAL_FILE}.bak.$(date +%F-%H%M%S)"
    echo -n "Saving current config as $PRE_RESTORE_BACKUP ... "
    if cp "$ORIGINAL_FILE" "$PRE_RESTORE_BACKUP" 2>/dev/null; then
        echo "${GREEN}OK${NC}"
    else
        echo "${RED}FAILED${NC}"
        return 1
    fi

    echo -n "Restoring to $ORIGINAL_FILE ... "
    if cp "$SELECTED_BACKUP" "$ORIGINAL_FILE" 2>/dev/null; then
        echo "${GREEN}OK${NC}"
    else
        echo "${RED}FAILED${NC}"
        return 1
    fi

    refresh_apt_lists
    echo "${YELLOW}Running apt update...${NC}"
    if apt update; then
        echo "${GREEN}✔ Restore successful${NC}"
    else
        echo "${RED}apt update failed. Undo: cp $PRE_RESTORE_BACKUP $ORIGINAL_FILE${NC}"
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
    local m
    if [[ -f "$UBUNTU_SOURCES" ]]; then
        m=$(grep -m1 '^URIs:' "$UBUNTU_SOURCES" 2>/dev/null | sed 's/^URIs:[[:space:]]*//' | awk '{print $1}')
        [[ -n "$m" ]] && echo "$m" && return
    fi
    if [[ -f "$SOURCES_FILE" ]]; then
        grep -m1 "^deb " "$SOURCES_FILE" 2>/dev/null | awk '{print $2}'
    fi
}

detect_sources_format() {
    if [[ -f "$UBUNTU_SOURCES" ]]; then
        echo "deb822"
    else
        echo "legacy"
    fi
}

validate_url() {
    [[ $1 =~ ^https?:// ]]
}

clear_sources_list_duplicates() {
    local active_lines
    active_lines=$(grep -cE '^deb ' "$SOURCES_FILE" 2>/dev/null || echo 0)
    if [[ "$active_lines" -gt 0 ]]; then
        cp "$SOURCES_FILE" "${SOURCES_FILE}.bak.$(date +%F-%H%M%S)" 2>/dev/null || true
        echo "# Cleared by apt-mirror-pro on $(date) — using ubuntu.sources (deb822)" >"$SOURCES_FILE"
        echo "${YELLOW}✔ Cleared duplicate deb lines from sources.list${NC}"
    fi
}

disable_ubuntu_deb822_sources() {
    if [[ ! -f "$UBUNTU_SOURCES" ]]; then
        return 0
    fi
    backup_ubuntu_sources
    rm -f "$UBUNTU_SOURCES"
    echo "${YELLOW}✔ Removed $UBUNTU_SOURCES (legacy sources.list mode)${NC}"
}

refresh_apt_lists() {
    apt clean
    rm -rf /var/lib/apt/lists/*
}

write_deb822_sources() {
    local mirror="$1"
    local codename="$2"
    local security_mirror="$3"

    backup_ubuntu_sources
    clear_sources_list_duplicates

    mirror="${mirror%/}"
    security_mirror="${security_mirror%/}"

    if [[ "$mirror" == "$security_mirror" ]]; then
        cat >"$UBUNTU_SOURCES" <<EOF
# Mirror set by apt-mirror-pro on $(date)
Types: deb
URIs: $mirror
Suites: $codename $codename-updates $codename-backports $codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    else
        cat >"$UBUNTU_SOURCES" <<EOF
# Mirror set by apt-mirror-pro on $(date)
Types: deb
URIs: $mirror
Suites: $codename $codename-updates $codename-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $security_mirror
Suites: $codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    fi
    echo "${GREEN}✔ Wrote deb822 → $UBUNTU_SOURCES${NC}"
}

write_legacy_sources() {
    local mirror="$1"
    local codename="$2"
    local security_mirror="$3"

    disable_ubuntu_deb822_sources

    cat >"$SOURCES_FILE" <<EOF
# Mirror set by apt-mirror-pro on $(date)
deb $mirror $codename main restricted universe multiverse
deb $mirror $codename-updates main restricted universe multiverse
deb $mirror $codename-backports main restricted universe multiverse
deb $security_mirror $codename-security main restricted universe multiverse

deb-src $mirror $codename main restricted universe multiverse
deb-src $mirror $codename-updates main restricted universe multiverse
deb-src $mirror $codename-backports main restricted universe multiverse
deb-src $security_mirror $codename-security main restricted universe multiverse
EOF
}

confirm_invalid_mirror() {
    echo "${YELLOW}Warning: mirror failed deep validation (may be syncing or incomplete).${NC}"
    read -rp "Continue anyway? (y/N): " cont
    [[ "$cont" =~ ^[Yy]$ ]]
}

update_sources() {
    local mirror=$1
    local security_override="${2:-}"
    local codename
    local security_mirror
    local fmt
    local snapshot_dir

    validate_url "$mirror" || {
        echo "${RED}Invalid URL${NC}"
        return 1
    }

    [[ $mirror != */ ]] && mirror="${mirror}/"

    if [[ -n "$security_override" ]]; then
        validate_url "$security_override" || {
            echo "${RED}Invalid security URL${NC}"
            return 1
        }
        [[ $security_override != */ ]] && security_override="${security_override}/"
        security_mirror="$security_override"
    elif [[ "$mirror" == "$OFFICIAL" ]]; then
        security_mirror="http://security.ubuntu.com/ubuntu/"
    else
        security_mirror="$mirror"
    fi

    codename=$(get_codename)

    echo "${YELLOW}Switching to:${NC} $mirror"
    if [[ "$security_mirror" != "$mirror" ]]; then
        echo "${YELLOW}Security:${NC} $security_mirror"
    fi
    snapshot_dir=$(backup_full_apt)
    echo "${GREEN}✔ Full snapshot: $snapshot_dir${NC}"
    backup_sources

    echo -n "Validating mirror... "
    if validate_mirror "${mirror%/}"; then
        echo "${GREEN}OK${NC}"
    else
        echo "${RED}FAILED${NC}"
        confirm_invalid_mirror || return 1
    fi

    if [[ "${security_mirror%/}/" != "${mirror%/}/" ]]; then
        echo -n "Validating security mirror... "
        if validate_mirror "${security_mirror%/}"; then
            echo "${GREEN}OK${NC}"
        else
            echo "${RED}FAILED${NC}"
            confirm_invalid_mirror || return 1
        fi
    fi

    fmt=$(detect_sources_format)
    if [[ "$fmt" == "deb822" ]]; then
        write_deb822_sources "$mirror" "$codename" "$security_mirror"
    else
        write_legacy_sources "$mirror" "$codename" "$security_mirror"
    fi

    refresh_apt_lists
    echo "${GREEN}✔ Updated successfully${NC}"
}

# ───────── SMART MIRROR TEST ─────────
test_mirror_score() {
    local base="${1%/}"
    local sec_base="${2:-}"
    local codename arch
    local lat_ms speed_kb score latency stats bytes time code pkg_url base_dist
    local tmpdir entry b s fail=0 pid pids=() range_end

    codename=$(get_codename)
    arch=$(get_arch)
    base_dist="$base/dists/$codename"
    sec_base="${sec_base%/}"
    range_end=$((PROBE_SPEED_BYTES - 1))

    tmpdir=$(mktemp -d 2>/dev/null) || {
        echo "unreachable"
        return 1
    }

    for entry in \
        "$base|$codename" \
        "$base|$codename-updates" \
        "$base|$codename-backports" \
        "${sec_base:-$base}|$codename-security"; do
        b="${entry%%|*}"
        s="${entry##*|}"
        (
            check_suite_probe "$b" "$s" || exit 1
        ) &
        pids+=($!)
    done

    (
        LC_ALL=C curl -4 --ipv4 -A "$UA" -s -L \
            --connect-timeout "$PROBE_CONNECT" --max-time "$PROBE_MAX" \
            -w "%{time_total}" -o /dev/null "$base_dist/InRelease" 2>/dev/null \
            >"$tmpdir/lat" || echo "0" >"$tmpdir/lat"
    ) &
    pids+=($!)

    pkg_url="$base_dist/main/binary-${arch}/Packages.gz"
    (
        LC_ALL=C curl -4 --ipv4 -A "$UA" -s -L \
            --connect-timeout "$PROBE_CONNECT" --max-time "$PROBE_MAX" \
            --range "0-$range_end" -o /dev/null \
            -w "%{size_download} %{time_total} %{http_code}" \
            "$pkg_url" 2>/dev/null >"$tmpdir/spd" || echo "0 0 000" >"$tmpdir/spd"
    ) &
    pids+=($!)

    for pid in "${pids[@]}"; do
        wait "$pid" || fail=1
    done

    latency=$(<"$tmpdir/lat")
    stats=$(<"$tmpdir/spd")
    rm -rf "$tmpdir"

    if [[ $fail -ne 0 ]]; then
        echo "unreachable"
        return 1
    fi

    lat_ms=$(LC_ALL=C awk "BEGIN {printf \"%d\", ${latency:-0}*1000}")

    bytes=$(awk '{print $1}' <<<"$stats")
    time=$(awk '{print $2}' <<<"$stats")
    code=$(awk '{print $3}' <<<"$stats")

    if [[ "$code" != "200" && "$code" != "206" ]] || [[ "${bytes:-0}" -lt 1000 ]]; then
        echo "slow:0"
        return 1
    fi

    speed_kb=0
    if [[ "${bytes:-0}" -gt 0 ]] && LC_ALL=C awk "BEGIN {exit !($time > 0.01)}"; then
        speed_kb=$(LC_ALL=C awk "BEGIN {printf \"%d\", $bytes/$time/1024}")
    fi

    if [[ "$speed_kb" -le 5 ]]; then
        echo "slow:${speed_kb}"
        return 1
    fi

    score=$(LC_ALL=C awk "BEGIN {printf \"%d\", ($lat_ms*0.6) + (100000/$speed_kb)*0.4}")
    echo "ok $score $lat_ms $speed_kb ${base}/"
    return 0
}

# ───────── AUTO SELECT ─────────
auto_select() {
    local -a results=()
    local name m result tested total i line best_url best_score
    local score lat spd url sorted

    echo "${YELLOW}Finding best mirror (suites + speed)...${NC}"
    echo "${YELLOW}Press Enter during tests to skip current mirror${NC}"

    tested=0
    total=${#MIRROR_NAMES[@]}

    setup_nonblock_input
    trap 'restore_input' EXIT INT TERM

    for name in "${MIRROR_NAMES[@]}"; do
        m="${MIRROR_URLS[$name]}"
        tested=$((tested + 1))

        SKIP_REQUESTED=false
        check_skip

        echo -n "[${tested}/${total}] $name ... "

        check_skip
        if [[ "$SKIP_REQUESTED" == "true" ]]; then
            echo "${YELLOW}skipped${NC}"
            continue
        fi

        result=$(test_mirror_score "${m%/}" "${MIRROR_SECURITY_URLS[$name]:-}")
        case "$result" in
            syncing) echo "${YELLOW}syncing${NC}" ;;
            unreachable) echo "${RED}unreachable${NC}" ;;
            slow:*) echo "${RED}too slow (${result#slow:} KB/s)${NC}" ;;
            ok\ *)
                score=$(awk '{print $2}' <<<"$result")
                lat=$(awk '{print $3}' <<<"$result")
                spd=$(awk '{print $4}' <<<"$result")
                url=$(awk '{print $5}' <<<"$result")
                echo "${GREEN}${lat}ms | ${spd} KB/s | score=${score}${NC}"
                results+=("$score $lat $spd $url")
                ;;
            *) echo "${RED}FAIL${NC}" ;;
        esac
    done

    restore_input
    trap - EXIT INT TERM

    if [[ ${#results[@]} -eq 0 ]]; then
        echo "${RED}No working mirror found${NC}"
        return 1
    fi

    mapfile -t sorted < <(printf '%s\n' "${results[@]}" | sort -n)

    echo
    echo "${BLUE}Top mirrors:${NC}"
    for i in "${!sorted[@]}"; do
        [[ $i -ge 3 ]] && break
        line="${sorted[$i]}"
        score=$(awk '{print $1}' <<<"$line")
        lat=$(awk '{print $2}' <<<"$line")
        spd=$(awk '{print $3}' <<<"$line")
        url=$(awk '{print $4}' <<<"$line")
        echo "  $((i + 1)). ${GREEN}$url${NC} (${lat}ms, ${spd} KB/s, score=${score})"
    done

    best_url=$(awk '{print $4}' <<<"${sorted[0]}")
    best_score=$(awk '{print $1}' <<<"${sorted[0]}")
    best_lat=$(awk '{print $2}' <<<"${sorted[0]}")
    best_spd=$(awk '{print $3}' <<<"${sorted[0]}")
    echo "${GREEN}Best: $best_url (score=${best_score})${NC}"

    LAST_BEST_NAME="Auto"
    LAST_BEST_URL="$best_url"
    LAST_BEST_MS="$best_lat"
    LAST_BEST_SPEED_KBPS="$best_spd"
    LAST_SCORE="$best_score"
    LAST_RUN_AT="$(date '+%F %T')"
    save_state

    local best_sec="" nurl
    for name in "${MIRROR_NAMES[@]}"; do
        nurl="${MIRROR_URLS[$name]}"
        [[ "${nurl%/}/" == "${best_url%/}/" ]] || continue
        best_sec="${MIRROR_SECURITY_URLS[$name]:-}"
        break
    done
    update_sources "$best_url" "$best_sec"
}

apply_mirror_by_name() {
    local name="$1"
    local url sec
    url="${MIRROR_URLS[$name]}"
    sec="${MIRROR_SECURITY_URLS[$name]:-}"
    update_sources "$url" "$sec"
}

# ───────── REGIONAL ─────────
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
    echo "${GREEN}APT Mirror Pro${NC}"
    echo "Codename: $(get_codename) | Arch: $(get_arch) | Format: $(detect_sources_format)"
    echo "Current: $(get_current_mirror)"
    if [[ -n "${LAST_BEST_URL:-}" ]]; then
        echo "Last Auto: ${LAST_BEST_URL} (${LAST_BEST_MS:-?}ms, ${LAST_BEST_SPEED_KBPS:-?} KB/s) @ ${LAST_RUN_AT:-?}"
    fi
    if [[ -n "$(detect_apt_busy_pids)" ]]; then
        echo "${YELLOW}APT busy — locks/processes active${NC}"
    fi
    echo "Custom mirrors: $CUSTOM_MIRRORS_FILE"
    echo

    local i=1
    for name in "${MIRROR_NAMES[@]}"; do
        echo "$i) $name"
        ((i++))
    done

    echo "$i) Auto (smart test)"
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
    echo "$i) Manage backups"
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

    run_apt=true
    apt_ok=true
    if (( choice >= 1 && choice <= ${#MIRROR_NAMES[@]} )); then
        name="${MIRROR_NAMES[$((choice - 1))]}"
        apply_mirror_by_name "$name" || apt_ok=false
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
            7) manage_backups; run_apt=false ;;
            8) exit 0 ;;
            *)
                echo "${RED}Internal menu mismatch (offset $offset)${NC}"
                sleep 1
                continue
                ;;
        esac
    fi

    if [[ "$run_apt" == "true" && "$apt_ok" != "false" ]]; then
        if wait_for_apt_lock 30; then
            echo "${YELLOW}Running apt update...${NC}"
            if ! apt update; then
                echo "${RED}apt update failed${NC}"
                read -rp "Roll back last full snapshot? [y/N]: " rb
                if [[ "$rb" =~ ^[Yy]$ ]]; then
                    rollback_latest_snapshot && apt update || true
                fi
            fi
        else
            echo "${YELLOW}APT is busy — skipped apt update (try again later)${NC}"
        fi
    fi

    read -rp "Enter..."
done
