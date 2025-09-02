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

# --- Step 1: Cache package list from the specified repository ---
echo "Fetching package list from repository '$repo'..."
mapfile -t repo_pkgs < <(pacman -Sl "$repo" | awk '{print $2}')

# --- Step 2: Get a list of installed packages for the current architecture ---
mapfile -t installed_pkgs < <(pacman -Qi | awk -v arch="$arch" '$1=="Name"{n=$3} ($1=="Architecture" && $3==arch){print n}')

# --- Step 3: Process each installed package ---
for pkg in "${installed_pkgs[@]}"; do
    # Check if the package exists in the repository
    if printf '%s\n' "${repo_pkgs[@]}" | grep -qx "$pkg"; then
        # Get the package dependencies from the repository
        deps=$(pacman -Si "$repo/$pkg" | awk -F': ' '/^Depends On/{print $2}')

        # Skip if there are no dependencies
        if [[ -z "$deps" || "$deps" == "<none>" ]]; then
            continue
        fi

        # --- Step 4: Check each dependency ---
        missing_deps=()
        for dep in $deps; do
            dep=${dep%,*}   # remove trailing commas
            dep=${dep%%=*}  # remove version constraints =1.2.3
            dep=${dep%%<*}  # remove version constraints <1.2.3
            dep=${dep%%>*}  # remove version constraints >1.2.3

            [[ -z "$dep" ]] && continue

            # Add dependency to list if it's not installed
            if ! pacman -Qq "$dep" &>/dev/null; then
                missing_deps+=("$dep")
            fi
        done

        # --- Step 5: Print package and missing dependencies ---
        if [[ ${#missing_deps[@]} -gt 0 ]]; then
            printf "%-30s needed:%s\n" "$pkg" "$(IFS=,; echo "${missing_deps[*]}")"
        fi
    fi
done