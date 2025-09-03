#!/usr/bin/env bash

# Script: Check missing dependencies (with version check) for installed packages
#         available in repos that support a given target architecture.
# Usage:  ./paclist2cachy.sh <target_architecture>
# Example: ./paclist2cachy.sh x86_64_v4

target_arch="$1"

# --- Validate parameter ---
if [[ -z "$target_arch" ]]; then
    echo "Error: target architecture not specified."
    echo "Usage: $0 <target_architecture>"
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

    # Cache package list for this repo (includes all arch)
    local repo_pkgs
    repo_pkgs=$(pacman -Sl "$repo" 2>/dev/null)
    [[ -z "$repo_pkgs" ]] && return 0

    echo "=== Repository: $repo (target arch: $target_arch) ==="

    for pkg in "${installed_pkgs[@]}"; do
        grep -q " $pkg " <<<"$repo_pkgs" || continue

        pkg_info=$(pacman -Si "$repo/$pkg" 2>/dev/null) || continue

        # Filter by architecture: only target_arch or 'any'
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
            needed="needed:$(IFS=,; echo "${missing_deps[*]}")"
        else
            needed=""
        fi
        printf "%-30s %s\n" "$pkg" "$needed"
    done
}

# --- Iterate through all repos ---
mapfile -t repos < <(pacman-conf --repo-list)
for repo in "${repos[@]}"; do
    scan_target_repo "$repo"
done