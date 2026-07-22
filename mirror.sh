#!/bin/bash
# APT Mirror Pro — Ubuntu/Debian mirror switcher + developer DNS helpers.
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
CYAN=$'\e[0;36m'
BOLD=$'\e[1m'
NC=$'\e[0m'

# ───────── MIRRORS ─────────
MIRROR_NAMES=(
"ArvanCloud"
"IranServer"
"Liara"
"AminIDC"
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
["Liara"]="http://linux-mirror.liara.ir/repository/ubuntu/"
["AminIDC"]="https://mirror.aminidc.com/ubuntu/"
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

# Separate security base (e.g. Shatel / Liara use a different security host)
declare -A MIRROR_SECURITY_URLS=(
["Shatel"]="http://mirror.shatel.ir/ubuntu-security/"
["Liara"]="http://linux-mirror.liara.ir/repository/ubuntu-security/"
)

OFFICIAL="http://archive.ubuntu.com/ubuntu/"

# Auto, Official, Regional, Reset, Custom, Show IR list, Manage backups, DNS tools, Exit
MENU_EXTRA=9
DNS_BACKUP_DIR="$CONFIG_DIR/dns-backups"
DNS_SLOW_MS=1800
HAVE_DIG=1

SKIP_REQUESTED=false
OLD_STTY=""

# ───────── GLOBAL COMMAND ─────────
create_command_link() {
    local script_path
    script_path="$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null)" || script_path="$(readlink -f "$0" 2>/dev/null)" || true
    # Skip when run via process substitution / pipe (e.g. bash <(curl ...))
    if [[ -z "$script_path" || ! -f "$script_path" || "$script_path" == /dev/fd/* || "$script_path" == /proc/self/fd/* ]]; then
        return 0
    fi
    if [[ ! -e "/usr/local/bin/mirror" ]]; then
        ln -s "$script_path" "/usr/local/bin/mirror"
        chmod +x "$script_path" 2>/dev/null || true
        echo "${GREEN}✔ Command 'mirror' installed → /usr/local/bin/mirror${NC}"
    fi
}

# ───────── ROOT CHECK ─────────
[[ $EUID -ne 0 ]] && echo "${RED}Run as root${NC}" && exit 1

create_command_link

mkdir -p "$CONFIG_DIR" "$BACKUP_SNAPSHOT_DIR" "$DNS_BACKUP_DIR"
touch "$CUSTOM_MIRRORS_FILE" 2>/dev/null || true

# ───────── DEPS & CUSTOM MIRRORS ─────────
ensure_deps() {
    local pkgs=()
    command -v curl >/dev/null 2>&1 || pkgs+=("curl")
    command -v dig >/dev/null 2>&1 || pkgs+=("dnsutils")
    if [[ ${#pkgs[@]} -gt 0 ]]; then
        apt update >/dev/null 2>&1 || true
        apt install -y "${pkgs[@]}" >/dev/null 2>&1 || true
    fi
    if ! command -v dig >/dev/null 2>&1; then
        HAVE_DIG=0
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

# ───────── DNS HELPERS ─────────
# Neutral groups for developer connectivity presets (not political messaging).
PROVIDER_NAMES=()
PROVIDER_DNS1=()
PROVIDER_DNS2=()
PROVIDER_GROUP=()

add_dns_provider() {
    PROVIDER_NAMES+=("$1")
    PROVIDER_DNS1+=("$2")
    PROVIDER_DNS2+=("$3")
    PROVIDER_GROUP+=("$4")
}

# Developer / regional resolvers commonly used for package registries & APIs
add_dns_provider "Shecan"            "178.22.122.100"  "185.51.200.2"    "dev"
add_dns_provider "403.online"        "10.202.10.202"   "10.202.10.102"   "dev"
add_dns_provider "Begzar"            "185.55.226.26"   "185.55.225.25"   "dev"
add_dns_provider "Electro"           "78.157.42.100"   "78.157.42.101"   "dev"
add_dns_provider "Radar"             "10.202.10.10"    "10.202.10.11"    "dev"
add_dns_provider "DynX"              "10.70.95.150"    "10.70.95.162"    "dev"
add_dns_provider "Bertina"           "193.186.32.32"   ""                "dev"
add_dns_provider "Shelter"           "94.103.125.157"  "94.103.125.158"  "dev"
add_dns_provider "Derak"             "193.151.128.100" "193.151.128.200" "dev"
add_dns_provider "Parspack-Tehran2"  "45.159.149.19"   "185.164.72.97"   "dev"
add_dns_provider "Parspack-Tehran3"  "185.8.174.140"   "130.185.77.69"   "dev"
add_dns_provider "Parspack-Tehran11" "195.177.255.170" "178.239.151.228" "dev"
# ISP resolvers
add_dns_provider "Shatel"            "85.15.1.14"      "85.15.1.15"      "isp"
add_dns_provider "Pishgaman"         "5.202.100.100"   "5.202.100.101"   "isp"
add_dns_provider "Mobin-net"         "10.104.88.8"     "10.104.88.9"     "isp"
add_dns_provider "AsiaTech"          "185.98.113.113"  "185.98.113.114"  "isp"
add_dns_provider "TCI"               "217.218.155.155" "217.218.127.127" "isp"
# National / other
add_dns_provider "DNS-Pro"           "87.107.110.109"  "87.107.110.110"  "national"
add_dns_provider "NIC"               "194.225.152.10"  ""                "national"
# Public resolvers
add_dns_provider "Cloudflare"        "1.1.1.1"         "1.0.0.1"         "public"
add_dns_provider "Google"            "8.8.8.8"         "8.8.4.4"         "public"
add_dns_provider "Quad9"             "9.9.9.9"         "149.112.112.112" "public"

dns_group_label() {
    case "$1" in
        dev)      echo "Developer DNS" ;;
        isp)      echo "ISP" ;;
        national) echo "National / Other" ;;
        public)   echo "Public" ;;
        *)        echo "$1" ;;
    esac
}

uses_systemd_resolved() {
    systemctl is-active --quiet systemd-resolved 2>/dev/null
}

print_current_dns() {
    echo ""
    echo -e "${CYAN}─── Current DNS ─────────────────────────────────────${NC}"
    if uses_systemd_resolved; then
        local dns_servers
        dns_servers=$(resolvectl status 2>/dev/null | awk '
            /^Global/        { iface = "Global"; next }
            /^Link [0-9]+/   { iface = $0; sub(/^Link [0-9]+ \(/, "", iface); sub(/\)[[:space:]]*$/, "", iface); next }
            /Current DNS Server:|DNS Servers:/ {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                print "  [" iface "] " line
            }
        ' || true)
        if [[ -n "${dns_servers}" ]]; then
            echo "${dns_servers}"
        else
            echo "  systemd-resolved active but no DNS servers reported."
        fi
    else
        local entries
        entries=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print "  " $2}' || true)
        if [[ -n "${entries}" ]]; then
            echo "${entries}"
        else
            echo "  /etc/resolv.conf has no nameserver entries."
        fi
    fi
}

set_dns() {
    local dns1="$1"
    local dns2="${2:-}"
    local name="$3"
    local dns_line="${dns1}"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    [[ -n "${dns2}" ]] && dns_line="${dns1} ${dns2}"

    mkdir -p "$DNS_BACKUP_DIR"

    if uses_systemd_resolved; then
        cp /etc/systemd/resolved.conf "${DNS_BACKUP_DIR}/resolved.conf.${ts}" 2>/dev/null || true
        sed -i '/^DNS=/d;/^FallbackDNS=/d' /etc/systemd/resolved.conf
        if grep -q '^\[Resolve\]' /etc/systemd/resolved.conf; then
            sed -i "/^\[Resolve\]/a DNS=${dns_line}" /etc/systemd/resolved.conf
        else
            printf '\n[Resolve]\nDNS=%s\n' "${dns_line}" >> /etc/systemd/resolved.conf
        fi
        systemctl restart systemd-resolved
        echo -e "${GREEN}DNS set to ${name} (${dns_line}) via systemd-resolved.${NC}"
        echo -e "${YELLOW}If DHCP/NetworkManager also sets per-link DNS, verify with status below.${NC}"
    else
        cp /etc/resolv.conf "${DNS_BACKUP_DIR}/resolv.conf.${ts}" 2>/dev/null || true
        {
            printf 'nameserver %s\n' "${dns1}"
            [[ -n "${dns2}" ]] && printf 'nameserver %s\n' "${dns2}"
        } >/etc/resolv.conf
        echo -e "${GREEN}DNS set to ${name} (${dns_line}) via /etc/resolv.conf.${NC}"
        echo -e "${YELLOW}Note: NetworkManager or cloud-init may overwrite this on reboot.${NC}"
    fi
    print_current_dns
}

restore_dns() {
    local choice latest ts
    ts=$(date +%Y%m%d-%H%M%S)
    echo ""
    echo -e "${BOLD}Restore DNS to:${NC}"
    echo "1) Previous backup   [default]"
    echo "2) System default    (remove custom DNS / use DHCP)"
    echo "0) Back"
    read -rp "Your choice [0-2, default=1]: " choice
    choice=${choice:-1}
    [[ "${choice}" == "0" ]] && return

    case "${choice}" in
        1)
            if uses_systemd_resolved; then
                latest=$(ls -t "${DNS_BACKUP_DIR}"/resolved.conf.* 2>/dev/null | head -n1 || true)
                if [[ -n "${latest}" ]]; then
                    cp "${latest}" /etc/systemd/resolved.conf
                    systemctl restart systemd-resolved
                    echo -e "${GREEN}Restored systemd-resolved from ${latest}.${NC}"
                else
                    echo "No backup found. Use option 2 for system default."
                fi
            else
                latest=$(ls -t "${DNS_BACKUP_DIR}"/resolv.conf.* 2>/dev/null | head -n1 || true)
                if [[ -n "${latest}" ]]; then
                    cp "${latest}" /etc/resolv.conf
                    echo -e "${GREEN}Restored /etc/resolv.conf from ${latest}.${NC}"
                else
                    echo "No backup found. Use option 2 for system default."
                fi
            fi
            ;;
        2)
            mkdir -p "$DNS_BACKUP_DIR"
            if uses_systemd_resolved; then
                cp /etc/systemd/resolved.conf "${DNS_BACKUP_DIR}/resolved.conf.${ts}" 2>/dev/null || true
                sed -i '/^DNS=/d;/^FallbackDNS=/d' /etc/systemd/resolved.conf
                systemctl restart systemd-resolved
                echo -e "${GREEN}Custom DNS removed. systemd-resolved will use DHCP-provided DNS.${NC}"
            else
                cp /etc/resolv.conf "${DNS_BACKUP_DIR}/resolv.conf.${ts}" 2>/dev/null || true
                printf 'nameserver 127.0.0.53\noptions edns0 trust-ad\n' >/etc/resolv.conf
                echo -e "${GREEN}Restored default stub resolver (127.0.0.53).${NC}"
            fi
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    print_current_dns
}

change_dns() {
    local last_group="" i d1 d2 dns_show choice idx
    echo ""
    echo -e "${BOLD}Available DNS providers:${NC}"
    for i in "${!PROVIDER_NAMES[@]}"; do
        local grp="${PROVIDER_GROUP[$i]}"
        if [[ "${grp}" != "${last_group}" ]]; then
            echo ""
            echo -e "${CYAN}── $(dns_group_label "${grp}") ──${NC}"
            last_group="${grp}"
        fi
        d1="${PROVIDER_DNS1[$i]}"
        d2="${PROVIDER_DNS2[$i]}"
        dns_show="${d1}"
        [[ -n "${d2}" ]] && dns_show="${d1}, ${d2}"
        printf "%2d) %-22s %s\n" "$((i + 1))" "${PROVIDER_NAMES[$i]}" "${dns_show}"
    done
    echo ""
    echo " 0) Back"
    read -rp "Your choice [0-${#PROVIDER_NAMES[@]}, default=1]: " choice
    choice=${choice:-1}
    [[ "${choice}" == "0" ]] && return
    if [[ ! "${choice}" =~ ^[0-9]+$ ]]; then
        echo "Invalid choice. No changes made."
        return
    fi
    idx=$((choice - 1))
    if (( idx >= 0 && idx < ${#PROVIDER_NAMES[@]} )); then
        set_dns "${PROVIDER_DNS1[$idx]}" "${PROVIDER_DNS2[$idx]}" "${PROVIDER_NAMES[$idx]}"
    else
        echo "Invalid choice. No changes made."
    fi
}

BENCH_RESOLVED=0
BENCH_REACHABLE=0
BENCH_AVG=""
BENCH_AVG_MS=0

bench_one_dns() {
    local server="$1"
    local total="$2"
    shift 2
    local targets=("$@")
    local total_ms=0 resolved=0 reachable=0
    local target ip elapsed code dig_out start end

    for target in "${targets[@]}"; do
        ip=""
        elapsed=0

        if [[ -n "${server}" ]]; then
            dig_out=$(timeout 3 dig +time=2 +tries=1 +notcp \
                +noall +answer +stats \
                "@${server}" "${target}" 2>&1 || true)
            ip=$(printf "%s" "${dig_out}" \
                | awk '{print $NF}' \
                | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | paste -sd, - || true)
            elapsed=$(printf "%s" "${dig_out}" \
                | grep "Query time" \
                | grep -oE '[0-9]+' | head -n1 || true)
            elapsed=${elapsed:-0}
        else
            start=$(date +%s%N)
            ip=$(timeout 3 getent hosts "${target}" 2>/dev/null \
                | awk '{print $1}' | paste -sd, - || true)
            end=$(date +%s%N)
            elapsed=$(( (end - start) / 1000000 ))
        fi

        if [[ -n "${ip}" ]]; then
            resolved=$((resolved + 1))
            total_ms=$((total_ms + elapsed))
            if [[ -n "${server}" ]]; then
                # Use first resolved IP for reachability probe
                local first_ip="${ip%%,*}"
                code=$(timeout 12 curl -s -o /dev/null -w '%{http_code}' \
                    -L --resolve "${target}:443:${first_ip}" \
                    --connect-timeout 8 --max-time 10 \
                    "https://${target}" 2>/dev/null) || code="000"
            else
                code=$(timeout 12 curl -s -o /dev/null -w '%{http_code}' \
                    -L --connect-timeout 8 --max-time 10 \
                    "https://${target}" 2>/dev/null) || code="000"
            fi
            # 403/451 often mean the origin rejects the client IP — still "resolved"
            if [[ "${code}" != "000" ]]; then
                reachable=$((reachable + 1))
            fi
        fi
    done

    BENCH_RESOLVED=${resolved}
    BENCH_REACHABLE=${reachable}
    if (( resolved > 0 )); then
        BENCH_AVG_MS=$((total_ms / resolved))
        BENCH_AVG="${BENCH_AVG_MS}ms"
    else
        BENCH_AVG_MS=999999
        BENCH_AVG="-"
    fi
}

benchmark_dns() {
    local scope scope_filter scope_label custom_input targets total
    local best_name="" best_idx=-1 best_score=-1 best_time=999999
    local i grp slow_tag status_text status_color
    local sys_reachable sys_avg_ms sys_color sys_status apply_best

    if [[ "${HAVE_DIG}" -ne 1 ]]; then
        echo ""
        echo -e "${RED}dig is not available — install dnsutils, then re-run.${NC}"
        return
    fi

    echo ""
    echo -e "${BOLD}Which group to benchmark?${NC}"
    echo "1) Developer DNS   [default]"
    echo "2) ISP"
    echo "3) National / Other"
    echo "4) Public"
    echo "5) All"
    echo "0) Back"
    read -rp "Your choice [0-5, default=1]: " scope
    scope=${scope:-1}
    [[ "${scope}" == "0" ]] && return
    case "${scope}" in
        1) scope_filter="dev"; scope_label="Developer DNS" ;;
        2) scope_filter="isp"; scope_label="ISP" ;;
        3) scope_filter="national"; scope_label="National / Other" ;;
        4) scope_filter="public"; scope_label="Public" ;;
        5) scope_filter="all"; scope_label="All" ;;
        *) scope_filter="dev"; scope_label="Developer DNS" ;;
    esac

    echo ""
    echo -e "${CYAN}Default targets: github.com  registry-1.docker.io  pypi.org  registry.npmjs.org${NC}"
    read -rp "Custom domains (space-separated) or Enter for defaults: " custom_input
    if [[ -n "${custom_input}" ]]; then
        # shellcheck disable=SC2206
        targets=(${custom_input})
    else
        targets=("github.com" "registry-1.docker.io" "pypi.org" "registry.npmjs.org")
    fi
    total=${#targets[@]}

    echo ""
    echo -e "${BOLD}Benchmarking [${scope_label}] — ${total} target(s).${NC}"
    echo -e "${YELLOW}This may take a few minutes.${NC}"
    echo ""
    printf "%-22s %-9s %s\n" "PROVIDER" "RESOLVE" "STATUS"
    printf "%-22s %-9s %s\n" "----------------------" "---------" "------------------------------"

    for i in "${!PROVIDER_NAMES[@]}"; do
        grp="${PROVIDER_GROUP[$i]}"
        if [[ "${scope_filter}" != "all" && "${grp}" != "${scope_filter}" ]]; then
            continue
        fi

        bench_one_dns "${PROVIDER_DNS1[$i]}" "${total}" "${targets[@]}"

        slow_tag=""
        (( BENCH_AVG_MS >= DNS_SLOW_MS && BENCH_RESOLVED > 0 )) && slow_tag=" [SLOW]"

        if (( BENCH_RESOLVED == 0 )); then
            status_color="${RED}"
            status_text="UNREACHABLE"
        elif (( BENCH_REACHABLE == total )); then
            status_color="${GREEN}"
            status_text="OK (${total}/${total})${slow_tag}"
        elif (( BENCH_REACHABLE == 0 )); then
            status_color="${RED}"
            status_text="no-http (0/${total})${slow_tag}"
        else
            status_color="${YELLOW}"
            status_text="partial (${BENCH_REACHABLE}/${total})${slow_tag}"
        fi

        printf "%-22s %-9s " "${PROVIDER_NAMES[$i]}" "${BENCH_AVG}"
        echo -e "${status_color}${status_text}${NC}"

        if (( BENCH_REACHABLE > 0 && BENCH_AVG_MS < DNS_SLOW_MS )); then
            if (( BENCH_REACHABLE > best_score )) \
                || { (( BENCH_REACHABLE == best_score )) && (( BENCH_AVG_MS < best_time )); }; then
                best_score="${BENCH_REACHABLE}"
                best_time="${BENCH_AVG_MS}"
                best_name="${PROVIDER_NAMES[$i]}"
                best_idx="${i}"
            fi
        fi
    done

    bench_one_dns "" "${total}" "${targets[@]}"
    sys_reachable="${BENCH_REACHABLE}"
    sys_avg_ms="${BENCH_AVG_MS}"
    if (( BENCH_RESOLVED == 0 )); then
        sys_color="${RED}"; sys_status="UNREACHABLE"
    elif (( BENCH_REACHABLE == total )); then
        sys_color="${GREEN}"; sys_status="OK (${total}/${total})"
    elif (( BENCH_REACHABLE == 0 )); then
        sys_color="${RED}"; sys_status="no-http (0/${total})"
    else
        sys_color="${YELLOW}"; sys_status="partial (${BENCH_REACHABLE}/${total})"
    fi
    printf "%-22s %-9s " "System (current)" "${BENCH_AVG}"
    echo -e "${sys_color}${sys_status}${NC}"

    echo ""
    if [[ -n "${best_name}" ]]; then
        if (( sys_reachable > best_score )) \
            || { (( sys_reachable == best_score )) && (( sys_avg_ms <= best_time )); }; then
            echo -e "${GREEN}>>> Current DNS already looks best for these targets.${NC}"
        else
            echo -e "${GREEN}${BOLD}>>> Suggested: ${best_name} — ${best_score}/${total} at ${best_time}ms${NC}"
            read -rp "Apply ${best_name} now? [y/N]: " apply_best
            apply_best=${apply_best:-N}
            if [[ "${apply_best}" =~ ^[Yy]$ ]]; then
                set_dns "${PROVIDER_DNS1[${best_idx}]}" "${PROVIDER_DNS2[${best_idx}]}" "${best_name}"
            fi
        fi
    else
        echo -e "${YELLOW}>>> No strong candidate. Try another group or different targets.${NC}"
    fi
}

test_connectivity() {
    local custom_input targets target http_code
    print_current_dns

    echo ""
    echo -e "${BOLD}Connectivity check (resolve + HTTPS):${NC}"
    echo -e "${CYAN}Default: github.com  registry-1.docker.io  pypi.org  registry.npmjs.org${NC}"
    read -rp "Custom domains (space-separated) or Enter for defaults: " custom_input
    if [[ -n "${custom_input}" ]]; then
        # shellcheck disable=SC2206
        targets=(${custom_input})
    else
        targets=("github.com" "registry-1.docker.io" "pypi.org" "registry.npmjs.org")
    fi
    echo ""
    for target in "${targets[@]}"; do
        if timeout 3 getent hosts "${target}" >/dev/null 2>&1; then
            http_code=$(timeout 12 curl -s -o /dev/null -w '%{http_code}' \
                --connect-timeout 8 --max-time 10 \
                "https://${target}" 2>/dev/null) || http_code="000"
            case "${http_code}" in
                000)
                    echo -e "  ${RED}[DOWN]${NC}      ${target} (connection failed)"
                    ;;
                403|451)
                    echo -e "  ${YELLOW}[HTTP]${NC}      ${target} (HTTP ${http_code} — origin may reject this IP)"
                    ;;
                *)
                    echo -e "  ${GREEN}[OK]${NC}        ${target} (HTTP ${http_code})"
                    ;;
            esac
        else
            echo -e "  ${RED}[NO-DNS]${NC}    ${target} (resolution failed)"
        fi
    done
    echo ""
    echo "Tip: use DNS benchmark to compare resolvers for these hosts."
}

dns_tools_menu() {
    local choice
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}DNS Tools${NC}"
        echo -e "${CYAN}=========${NC}"
        echo "1) Set DNS provider"
        echo "2) Restore DNS"
        echo "3) Show current DNS"
        echo "4) Test connectivity"
        echo "5) Benchmark DNS"
        echo "0) Back"
        read -rp "Your choice [0-5]: " choice
        case "${choice}" in
            1) change_dns ;;
            2) restore_dns ;;
            3) print_current_dns ;;
            4) test_connectivity ;;
            5) benchmark_dns ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done
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
    echo "$i) DNS tools"
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
            8) dns_tools_menu; run_apt=false ;;
            9) exit 0 ;;
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
