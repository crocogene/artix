#!/usr/bin/env bash
# Script: Check missing dependencies (with version check) for installed packages
#         available in repos that support a given target architecture.

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] <target_architecture>

Check installed packages against repositories for a target architecture
and list missing dependencies.

Options:
  -n, --needed_only   Show only packages with missing dependencies.
  -h, --help          Show this help message.

Examples:
  $0 x86_64_v4
  $0 x86_64_v4 --needed_only
EOF
}

# --- Parse arguments ---
needed_only=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--needed_only)
            needed_only=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Error: unknown option '$1'" >&2
            show_help
            exit 1
            ;;
        *)
            target_arch="$1"
            shift
            ;;
    esac
done

# --- Validate parameter ---
if [[ -z "$target_arch" ]]; then
    echo "Error: target architecture not specified."
    show_help
    exit 1
fi

current_arch=$(uname -m)

# 1) Target arch must differ from uname -m
if [[ "$target_arch" == "$current_arch" ]]; then
    echo "Error: target architecture ($target_arch) must differ from current architecture ($current_arch)."
    exit 1
fi

# 2) Target arch must be present in pacman.conf Architecture OR it must be 'auto'
arch_list=$(pacman-conf Architecture | tr -d '&' | xargs)
if ! grep -qwE "$target_arch|auto" <<<"$arch_list"; then
    echo "Error: target architecture '$target_arch' is not listed in pacman configuration."
    echo "Available architectures: $arch_list"
    exit 1
fi

# --- Get installed packages for the CURRENT architecture ---
mapfile -t installed_pkgs < <(pacman -Qi | awk -v arch="$current_arch" '
    $1=="Name"        { n=$3 }
    $1=="Architecture" && $3==arch { print n }
')

# --- Version compare via vercmp ---
compare_versions() {
    local ver1="$1" op="$2" ver2="$3"
    local res
    res=$(vercmp "$ver1" "$ver2")
    case "$op" in
        "=")  [[ $res -eq 0 ]] ;;
        ">")  [[ $res -gt 0 ]] ;;
        "<")  [[ $res -lt 0 ]] ;;
        ">=") [[ $res -ge 0 ]] ;;
        "<=") [[ $res -le 0 ]] ;;
        *)    return 1 ;;
    esac
}

# --- Function: scan a single repository for packages and dependencies ---
scan_target_repo() {
    local repo="$1"

    local repo_pkgs
    repo_pkgs=$(pacman -Sl "$repo" 2>/dev/null)
    [[ -z "$repo_pkgs" ]] && return 0

    local output=""
    for pkg in "${installed_pkgs[@]}"; do
        grep -q " $pkg " <<<"$repo_pkgs" || continue

        pkg_info=$(pacman -Si "$repo/$pkg" 2>/dev/null) || continue
        pkg_arch=$(awk -F': *' '/^Architecture/{print $2}' <<<"$pkg_info")
        [[ "$pkg_arch" == "$target_arch" || "$pkg_arch" == "any" ]] || continue

        deps=$(awk -F': *' '/^Depends On/{print $2}' <<<"$pkg_info" | sed 's/^<none>$//;s/^None$//')

        missing_deps=()
        for dep in $deps; do
            [[ -z "$dep" ]] && continue
            dep_pkg_name="${dep%%[<>=]*}"
            installed_ver=$(pacman -Q "$dep_pkg_name" 2>/dev/null | awk '{print $2}')

            if [[ -z "$installed_ver" ]]; then
                missing_deps+=("$dep")
                continue
            fi

            if [[ "$dep" =~ (>=|<=|=|>|<)(.+) ]]; then
                op="${BASH_REMATCH[1]}"
                req_ver="${BASH_REMATCH[2]}"
                if ! compare_versions "$installed_ver" "$op" "$req_ver"; then
                    missing_deps+=("$dep")
                fi
            fi
        done

        if (( ${#missing_deps[@]} )); then
            needed_list=()
            for dep in "${missing_deps[@]}"; do
                dep_pkg_name="${dep%%[<>=]*}"
                installed_ver=$(pacman -Q "$dep_pkg_name" 2>/dev/null | awk '{print $2}')
                if [[ -n "$installed_ver" && "$dep" =~ [0-9] ]]; then
                    needed_list+=("${dep}(${installed_ver})")
                else
                    needed_list+=("$dep")
                fi
            done
            needed="needed:$(IFS=,; echo "${needed_list[*]}")"
        else
            needed=""
        fi

        # Skip output if needed_only is true and there are no missing deps
        if $needed_only && [[ -z "$needed" ]]; then
            continue
        fi

        output+=$(printf "%-30s %s" "$pkg" "$needed"; echo)
    done

    if [[ -n "$output" ]]; then
        echo "=== Repository: $repo (target arch: $target_arch) ==="
        echo -e "$output"
    fi
}

# --- Iterate through all repos ---
mapfile -t repos < <(pacman-conf --repo-list)
for repo in "${repos[@]}"; do
    scan_target_repo "$repo"
done