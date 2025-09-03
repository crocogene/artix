#!/usr/bin/env bash
# Script: Check missing dependencies (with version check) for installed packages
#         available in repos that support a given target architecture.

show_help() {
    cat <<EOF
Usage: $0 <target_arch> [--needed_only]

Options:
  --needed_only   Show only packages that have missing or mismatched dependencies

Examples:
  $0 x86_64_v4
  $0 x86_64_v4 --needed_only
EOF
}

[[ $# -lt 1 ]] && { show_help; exit 1; }

target_arch="$1"
needed_only=false
[[ "$2" == "--needed_only" ]] && needed_only=true

current_arch=$(uname -m)
arch_list=$(pacman-conf Architecture | sed 's/&//')

# Validate target architecture
if ! grep -qx "$target_arch" <<<"$arch_list" && ! grep -qx "auto" <<<"$arch_list"; then
    echo "Error: Target architecture '$target_arch' is not in pacman.conf."
    exit 1
fi
if [[ "$target_arch" == "$current_arch" ]]; then
    echo "Error: Target architecture must differ from current architecture ($current_arch)."
    exit 1
fi

# (kept for potential future use)
compare_versions() {
    local v1="$1" op="$2" v2="$3"
    local res
    res=$(vercmp "$v1" "$v2")
    case "$op" in
        '>')  [[ $res -gt 0 ]];;
        '>=') [[ $res -ge 0 ]];;
        '<')  [[ $res -lt 0 ]];;
        '<=') [[ $res -le 0 ]];;
        '='|'==') [[ $res -eq 0 ]];;
        *)    return 1;;
    esac
}

scan_target_repo() {
    local repo="$1"

    # Get package names from the repo (no arch info here)
    repo_pkgs=$(pacman -Sl "$repo" 2>/dev/null | awk '{print $2}')
    [[ -z "$repo_pkgs" ]] && return 0

    repo_out=""
    for pkg in $repo_pkgs; do
        # Must be installed locally
        pkg_info=$(pacman -Qi "$pkg" 2>/dev/null) || continue

        # Get target repo package info once; check its Architecture matches target_arch (or 'any')
        target_pkg_info=$(pacman -Si "$repo/$pkg" 2>/dev/null) || continue
        target_pkg_arch=$(awk -F': *' '/^Architecture/{print $2}' <<<"$target_pkg_info")
        [[ "$target_pkg_arch" == "$target_arch" || "$target_pkg_arch" == "any" ]] || continue

        # Extract Depends On from the same Si output
        deps=$(awk -F': *' '/^Depends On/{print $2}' <<<"$target_pkg_info" | sed 's/<none>//g; s/None//g')

        needed_list=()
        for dep in $deps; do
            [[ -z "$dep" ]] && continue
            dep_name="${dep%%[<>=]*}"

            # Info from target repo for dependency
            target_dep_info=$(pacman -Si "$repo/$dep_name" 2>/dev/null) || continue
            target_name=$(awk -F': *' '/^Name/{print $2}' <<<"$target_dep_info")
            target_ver=$(awk -F': *' '/^Version/{print $2}' <<<"$target_dep_info")
            [[ -z "$target_name" ]] && continue

            # Info about installed dependency
            dep_info=$(pacman -Qi "$dep_name" 2>/dev/null)
            installed_name=$(awk -F': *' '/^Name/{print $2}' <<<"$dep_info")
            installed_ver=$(awk -F': *' '/^Version/{print $2}' <<<"$dep_info")

            if [[ -z "$installed_name" ]]; then
                # Not installed at all
                needed_list+=("$target_name $target_ver")
                continue
            fi

            # If installed but version differs from target repo version
            if [[ "$installed_ver" != "$target_ver" ]]; then
                needed_list+=("$target_name $target_ver($installed_ver)")
            fi
        done

        if (( ${#needed_list[@]} )); then
            needed_out="needed:$(IFS=,; echo "${needed_list[*]}")"
        else
            needed_out=""
        fi

        if ! $needed_only || [[ -n "$needed_out" ]]; then
            printf -v repo_out '%s%-30s %s\n' "$repo_out" "$pkg" "$needed_out"
        fi
    done

    if [[ -n "$repo_out" ]]; then
        echo "=== Repository: $repo (target arch: $target_arch) ==="
        printf "%s" "$repo_out"
    fi
}

mapfile -t repos < <(pacman-conf --repo-list)
for repo in "${repos[@]}"; do
    scan_target_repo "$repo"
done