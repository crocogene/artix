#!/usr/bin/env bash
# Script: Check missing dependencies (with version check) for installed packages
#         available in repos that support a given target architecture.

print_help() {
    cat <<EOF
Usage: $0 <target_arch> [options]

Options:
  -n, --needed_only    Show only packages with missing or mismatched dependencies
  -h, --help           Show this help message

Examples:
  $0 x86_64_v4
  $0 x86_64_v4 --needed_only
EOF
}

# ============================
# Parse arguments
# ============================
needed_only=false
target_arch=""

for arg in "$@"; do
    case "$arg" in
        -n|--needed_only)
            needed_only=true
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            if [[ -z "$target_arch" ]]; then
                target_arch="$arg"
            else
                echo "Error: unexpected argument '$arg'" >&2
                print_help
                exit 1
            fi
            ;;
    esac
done

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

# Build list of installed packages filtered by current_arch
mapfile -t installed_pkgs < <(
    pacman -Qi |
    awk -v arch="$current_arch" '
        /^Name/ {name=$3}
        /^Architecture/ {if ($3==arch || $3=="any") print name}
    '
)

if [[ ${#installed_pkgs[@]} -eq 0 ]]; then
    echo "Error: No installed packages match current architecture '$current_arch'."
    exit 1
fi

# Function for version comparison (kept for future use)
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
    repo_out=""

    # Loop over installed packages
    for pkg in "${installed_pkgs[@]}"; do
        # Get target repo package info once; skip if not found
        target_pkg_info=$(pacman -Si "$repo/$pkg" 2>/dev/null) || continue
        target_pkg_arch=$(awk -F': *' '/^Architecture/{print $2}' <<<"$target_pkg_info")
        [[ "$target_pkg_arch" == "$target_arch" ]] || continue

        # Extract Depends On
        deps=$(awk -F': *' '/^Depends On/{print $2}' <<<"$target_pkg_info" | sed 's/<none>//g; s/None//g')

        needed_list=()
        for dep in $deps; do
            [[ -z "$dep" ]] && continue
            [[ "$dep" =~ ^([^<>=]+)([<>=]*)(.*)$ ]] && dep_name="${BASH_REMATCH[1]}" dep_op="${BASH_REMATCH[2]}" dep_version="${BASH_REMATCH[3]}"

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
                needed_list+=("$target_name $target_ver")
                continue
            fi

            if [[ -n "$dep_version" && "$installed_ver" != "$target_ver" ]]; then
                needed_list+=("$target_name $target_ver($installed_ver)")
            fi
        done

        if (( ${#needed_list[@]} )); then
            needed_out="needed:$(IFS=,; echo "${needed_list[*]}")"
        else
            needed_out=""
        fi

        $needed_only && [[ -z "$needed_out" ]] && continue

        printf -v repo_out '%s%-30s %s\n' "$repo_out" "$pkg" "$needed_out"

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