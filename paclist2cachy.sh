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

# --- Get installed packages for the CURRENT architecture ---
mapfile -t installed_pkgs < <(pacman -Qi | awk -v arch="$current_arch" '
    $1=="Name" { n=$3 }
    $1=="Architecture" && $3==arch { print n }
')

# --- Version compare via vercmp ---
compare_versions() {
    local v1="$1" op="$2" v2="$3"
    local res
    res=$(vercmp "$v1" "$v2")
    case "$op" in
        "=")  [[ $res -eq 0 ]] ;;
        ">")  [[ $res -gt 0 ]] ;;
        "<")  [[ $res -lt 0 ]] ;;
        ">=") [[ $res -ge 0 ]] ;;
        "<=") [[ $res -le 0 ]] ;;
        *)    return 1 ;;
    esac
}

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

        needed_list=()
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