#!/usr/bin/env bash

. $(dirname "$0")/opts.sh

mkfs.vfat -n $esp_label -F 32 $esp_part
mkfs.btrfs $tank_part -L $tank_label --force
mount -o $btrfs_opt /dev/disk/by-label/$tank_label /mnt
cd /mnt
btrfs subvol create {@,@home,@cache,@swap,@snapshots}  
cd ..
umount /mnt
. $(dirname "$0")/mountfs.sh