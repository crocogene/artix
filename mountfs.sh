#!/usr/bin/env bash

. $(dirname "$0")/btrfs_opt.sh

mount -o $OPT,subvol=/@ /dev/disk/by-label/tank /mnt   
mkdir -p /mnt/{boot,home,var/cache,swap,.snapshots}
mount -o $OPT,subvol=/@home /dev/disk/by-label/tank /mnt/home
mount -o $OPT,subvol=/@cache /dev/disk/by-label/tank /mnt/var/cache
mount -o $OPT,subvol=/@swap /dev/disk/by-label/tank /mnt/swap
mount -o $OPT,subvol=/@snapshots /dev/disk/by-label/tank /mnt/.snapshots
mount -o noatime /dev/disk/by-label/ESP /mnt/boot