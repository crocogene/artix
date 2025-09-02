#!/usr/bin/env bash

# Script: Check dependencies of installed packages available in a given repository
# Usage: ./paclist2cachy.sh <repository_name>
# Example: ./paclist2cachy.sh cachyos-znver4

repo="$1"

# --- Validate input parameter ---
if [[ -z "$repo" ]]; then
    echo "Error: repository name not specified."
    echo "Usage: $0 <repository_name>"
    exit 1
fi

# --- Check if repository exists using pacman-conf ---
if ! pacman-conf -r "$repo" &>/dev/null; then
    echo "Error: repository '$repo' not found in pacman configuration."
    echo "Available repositories:"
    pacman-conf --repo-list
    exit 1
fi

# --- Get system architecture ---
arch=$(uname -m)

# --- Get list of installed packages for the current architecture ---
mapfile -t installed_pkgs < <(pacman -Qi | awk -v arch="$arch" '$1=="Name"{n=$3} ($1=="Architecture" && $3==arch){print n}')

# --- Check each installed package ---
for pkg in "${installed_pkgs[@]}"; do
    # Check if the package exists in the specified repository
    if pacman -Sl "$repo" | grep -q " $pkg "; then
        # Get dependencies and clean out <none> / None
        deps=$(pacman -Si "$repo/$pkg" | awk -F': ' '/^Depends On/{print $2}' | sed 's/^<none>$//;s/^None$//')

        missing_deps=()
        for dep in $deps; do
            dep=${dep%,*}   # remove trailing commas
            dep=${dep%%=*}  # remove version constraints =1.2.3
            dep=${dep%%<*}  # remove version constraints <1.2.3
            dep=${dep%%>*}  # remove version constraints >1.2.3

            [[ -z "$dep" ]] && continue

            # Add to list if not installed
            if ! pacman -Qq "$dep" &>/dev/null; then
                missing_deps+=("$dep")
            fi
        done

        # Build needed string
        if (( ${#missing_deps[@]} )); then
            needed="needed:$(IFS=,; echo "${missing_deps[*]}")"
        else
            needed=""
        fi

        printf "%-30s %s\n" "$pkg" "$needed"
    fi
done