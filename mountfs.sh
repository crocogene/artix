#!/usr/bin/env bash

. $(dirname "$0")/opts.sh

mount -o $btrfs_opt,subvol=/@ /dev/disk/by-label/$tank_label /mnt   
mkdir -p /mnt/{boot,home,var/cache,swap,.snapshots}
mount -o $btrfs_opt,subvol=/@home /dev/disk/by-label/$tank_label /mnt/home
mount -o $btrfs_opt,subvol=/@cache /dev/disk/by-label/$tank_label /mnt/var/cache
mount -o $btrfs_opt,subvol=/@swap /dev/disk/by-label/$tank_label /mnt/swap
mount -o $btrfs_opt,subvol=/@snapshots /dev/disk/by-label/$tank_label /mnt/.snapshots
mount -o noatime /dev/disk/by-label/$esp_label /mnt/boot