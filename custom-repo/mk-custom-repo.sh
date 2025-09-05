#!/bin/bash

# Script to automate creating a local Arch Linux repository by copying latest built packages
# from specified repositories in pacman.conf, based on pkgs2copy.txt file.
# Each line in pkgs2copy.txt: <repo>/<pkg>
# Downloads package and .sig using pacman -Sw, copies to script's dir if not exists,
# adds to custom-repo.db.tar.xz with --prevent-downgrade, outputs message if added.
# Script can be run from any directory; works relative to its own location.

set -euo pipefail  # Strict mode for better error handling

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CUSTOM_REPO=$(basename "$SCRIPT_DIR")
DB_FILE="$SCRIPT_DIR/$CUSTOM_REPO.db.tar.xz"
PKGS_FILE="$SCRIPT_DIR/pkgs2copy.txt"
CACHE_DIR=$(pacman -Dv | grep Cache | awk '{print $3}' | sed 's|/$||')
ARCH=$(uname -m)
ARCH_LIST=$(pacman-conf Architecture | sed 's/&//')
REPO_LIST=$(pacman-conf --repo-list | grep -v "^$CUSTOM_REPO$") 

# Check if required tools are available
if ! command -v pacman &> /dev/null; then
    echo "Error: pacman not found. This script requires pacman"
    exit 1
fi
if ! command -v repo-add &> /dev/null; then
    echo "Error: repo-add not found. Install pacman-contrib"
    exit 1
fi
if [ ! -f "$PKGS_FILE" ]; then
    echo "Error: $PKGS_FILE not found in script's directory"
    exit 1
fi

# Protect form beeing run in system dirs
if [[ "$CUSTOM_REPO" == "root" || "$CUSTOM_REPO" == "usr" ]]; then
    echo "Error: Don't run script from system directories"
    exit 1
fi

new_files_added=0

# Read each line from pkgs2copy.txt
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue  # Skip empty or commented lines
    fi

    repo_n_pkg="$line"  # <repo>/<pkg>
    IFS=/ read -r repo pkg <<< "$repo_n_pkg"; repo="${repo// /}"; pkg="${pkg// /}";

    if [[ "$repo" == "" ]]; then
        echo "Skipping: no repo in line $repo_n_pkg"
        continue
    fi

    if [[ "$pkg" == "" ]]; then
        echo "Skipping: no package in line $repo_n_pkg"
        continue
    fi

    if [[ "$repo" == "$CUSTOM_REPO" ]]; then
        echo "Skipping: $repo_n_pkg refers to the repo currently being assembled"
        continue
    fi

    if ! printf '%s\n' "${REPO_LIST[@]}" | grep -Fxq -- "$repo"; then
        echo "Skipping: Repo $repo not found in pacman.conf"
        continue    
    fi

    # Get the filename of the latest package version
    filename=$(pacman -Sp --print-format "%f" "$repo_n_pkg" 2>/dev/null || true)
    if [[ -z "$filename" ]]; then
        echo "Skipping: Package $pkg not found in repository $repo"
        continue
    fi

    # Check if supported extension
    if [[ ! "$filename" =~ \.pkg\.tar\.(zst|xz)$ ]]; then
        echo "Skipping: Unsupported package format for $filename (only .pkg.tar.zst or .pkg.tar.xz)"
        continue
    fi

    # Check if file already exists in script's dir
    if [ -f "$SCRIPT_DIR/$filename" ]; then
        continue
    fi

    # Download the package (and .sig if available) to cache
    if ! pacman -Sw --noconfirm "$repo_pkg" &> /dev/null; then
        echo "Skipping: Failed to download $repo_pkg"
        continue
    fi

    # Copy package to script's dir
    cp -n "$CACHE_DIR/$filename" "$SCRIPT_DIR"

    # Copy .sig if exists
    sig_file="$filename.sig"
    if [ -f "$CACHE_DIR/$sig_file" ]; then
        cp -n "$CACHE_DIR/$sig_file" "$SCRIPT_DIR"
    fi

    # Add to local repo DB with --prevent-downgrade
    repo-add --prevent-downgrade "$DB_FILE" "$SCRIPT_DIR/$filename"

    new_files_added=1

    # Output message
    echo "New package added $filename"

done < "$PKGS_FILE"

(( flag == 0 )) && echo "No new packages have been added"
